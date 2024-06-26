use magnus::encoding::{EncodingCapable, Index};
use magnus::{
    class, prelude::*, r_hash::ForEach, Float, Integer, IntoValue, RArray, RHash, RString, Ruby,
    TryConvert, Value,
};
use polars::prelude::*;
use polars_core::utils::any_values_to_supertype_and_n_dtypes;

use super::{struct_dict, ObjectValue, Wrap};

use crate::rb_modules::utils;
use crate::{RbPolarsErr, RbResult, RbSeries};

impl IntoValue for Wrap<AnyValue<'_>> {
    fn into_value_with(self, ruby: &Ruby) -> Value {
        match self.0 {
            AnyValue::UInt8(v) => ruby.into_value(v),
            AnyValue::UInt16(v) => ruby.into_value(v),
            AnyValue::UInt32(v) => ruby.into_value(v),
            AnyValue::UInt64(v) => ruby.into_value(v),
            AnyValue::Int8(v) => ruby.into_value(v),
            AnyValue::Int16(v) => ruby.into_value(v),
            AnyValue::Int32(v) => ruby.into_value(v),
            AnyValue::Int64(v) => ruby.into_value(v),
            AnyValue::Float32(v) => ruby.into_value(v),
            AnyValue::Float64(v) => ruby.into_value(v),
            AnyValue::Null => ruby.qnil().as_value(),
            AnyValue::Boolean(v) => ruby.into_value(v),
            AnyValue::String(v) => ruby.into_value(v),
            AnyValue::StringOwned(v) => ruby.into_value(v.as_str()),
            AnyValue::Categorical(idx, rev, arr) | AnyValue::Enum(idx, rev, arr) => {
                let s = if arr.is_null() {
                    rev.get(idx)
                } else {
                    unsafe { arr.deref_unchecked().value(idx as usize) }
                };
                s.into_value()
            }
            AnyValue::Date(v) => utils().funcall("_to_ruby_date", (v,)).unwrap(),
            AnyValue::Datetime(v, time_unit, time_zone) => {
                let time_unit = time_unit.to_ascii();
                utils()
                    .funcall("_to_ruby_datetime", (v, time_unit, time_zone.clone()))
                    .unwrap()
            }
            AnyValue::Duration(v, time_unit) => {
                let time_unit = time_unit.to_ascii();
                utils()
                    .funcall("_to_ruby_duration", (v, time_unit))
                    .unwrap()
            }
            AnyValue::Time(v) => utils().funcall("_to_ruby_time", (v,)).unwrap(),
            AnyValue::Array(v, _) | AnyValue::List(v) => RbSeries::new(v).to_a().into_value(),
            ref av @ AnyValue::Struct(_, _, flds) => struct_dict(av._iter_struct_av(), flds),
            AnyValue::StructOwned(payload) => struct_dict(payload.0.into_iter(), &payload.1),
            AnyValue::Object(v) => {
                let object = v.as_any().downcast_ref::<ObjectValue>().unwrap();
                object.to_object()
            }
            AnyValue::ObjectOwned(v) => {
                let object = v.0.as_any().downcast_ref::<ObjectValue>().unwrap();
                object.to_object()
            }
            AnyValue::Binary(v) => RString::from_slice(v).into_value(),
            AnyValue::BinaryOwned(v) => RString::from_slice(&v).into_value(),
            AnyValue::Decimal(v, scale) => utils()
                .funcall("_to_ruby_decimal", (v.to_string(), -(scale as i32)))
                .unwrap(),
        }
    }
}

impl<'s> TryConvert for Wrap<AnyValue<'s>> {
    fn try_convert(ob: Value) -> RbResult<Self> {
        if ob.is_kind_of(class::true_class()) || ob.is_kind_of(class::false_class()) {
            Ok(AnyValue::Boolean(bool::try_convert(ob)?).into())
        } else if let Some(v) = Integer::from_value(ob) {
            Ok(AnyValue::Int64(v.to_i64()?).into())
        } else if let Some(v) = Float::from_value(ob) {
            Ok(AnyValue::Float64(v.to_f64()).into())
        } else if let Some(v) = RString::from_value(ob) {
            if v.enc_get() == Index::utf8() {
                Ok(AnyValue::StringOwned(v.to_string()?.into()).into())
            } else {
                Ok(AnyValue::BinaryOwned(unsafe { v.as_slice() }.to_vec()).into())
            }
        // call is_a? for ActiveSupport::TimeWithZone
        } else if ob.funcall::<_, _, bool>("is_a?", (class::time(),))? {
            let sec = ob.funcall::<_, _, i64>("to_i", ())?;
            let nsec = ob.funcall::<_, _, i64>("nsec", ())?;
            let v = sec * 1_000_000_000 + nsec;
            // TODO support time zone when possible
            // https://github.com/pola-rs/polars/issues/9103
            Ok(AnyValue::Datetime(v, TimeUnit::Nanoseconds, &None).into())
        } else if ob.is_nil() {
            Ok(AnyValue::Null.into())
        } else if let Some(dict) = RHash::from_value(ob) {
            let len = dict.len();
            let mut keys = Vec::with_capacity(len);
            let mut vals = Vec::with_capacity(len);
            dict.foreach(|k: Value, v: Value| {
                let key = String::try_convert(k)?;
                let val = Wrap::<AnyValue>::try_convert(v)?.0;
                let dtype = DataType::from(&val);
                keys.push(Field::new(&key, dtype));
                vals.push(val);
                Ok(ForEach::Continue)
            })?;
            Ok(Wrap(AnyValue::StructOwned(Box::new((vals, keys)))))
        } else if let Some(v) = RArray::from_value(ob) {
            if v.is_empty() {
                Ok(Wrap(AnyValue::List(Series::new_empty("", &DataType::Null))))
            } else {
                let list = v;

                let mut avs = Vec::with_capacity(25);
                let mut iter = list.each();

                for item in (&mut iter).take(25) {
                    avs.push(Wrap::<AnyValue>::try_convert(item?)?.0)
                }

                let (dtype, _n_types) =
                    any_values_to_supertype_and_n_dtypes(&avs).map_err(RbPolarsErr::from)?;

                // push the rest
                avs.reserve(list.len());
                for item in iter {
                    avs.push(Wrap::<AnyValue>::try_convert(item?)?.0)
                }

                let s = Series::from_any_values_and_dtype("", &avs, &dtype, true)
                    .map_err(RbPolarsErr::from)?;
                Ok(Wrap(AnyValue::List(s)))
            }
        } else if ob.is_kind_of(crate::rb_modules::datetime()) {
            let sec: i64 = ob.funcall("to_i", ())?;
            let nsec: i64 = ob.funcall("nsec", ())?;
            Ok(Wrap(AnyValue::Datetime(
                sec * 1_000_000_000 + nsec,
                TimeUnit::Nanoseconds,
                &None,
            )))
        } else if ob.is_kind_of(crate::rb_modules::date()) {
            // convert to DateTime for UTC
            let v = ob
                .funcall::<_, _, Value>("to_datetime", ())?
                .funcall::<_, _, Value>("to_time", ())?
                .funcall::<_, _, i64>("to_i", ())?;
            Ok(Wrap(AnyValue::Date((v / 86400) as i32)))
        } else if ob.is_kind_of(crate::rb_modules::bigdecimal()) {
            let (sign, digits, _, exp): (i8, String, i32, i32) = ob.funcall("split", ()).unwrap();
            let (mut v, scale) = abs_decimal_from_digits(digits, exp).ok_or_else(|| {
                RbPolarsErr::other("BigDecimal is too large to fit in Decimal128".into())
            })?;
            if sign < 0 {
                // TODO better error
                v = v.checked_neg().unwrap();
            }
            Ok(Wrap(AnyValue::Decimal(v, scale)))
        } else {
            Err(RbPolarsErr::other(format!(
                "object type not supported {:?}",
                ob
            )))
        }
    }
}

fn abs_decimal_from_digits(digits: String, exp: i32) -> Option<(i128, usize)> {
    let exp = exp - (digits.len() as i32);
    match digits.parse::<i128>() {
        Ok(mut v) => {
            let scale = if exp > 0 {
                v = 10_i128
                    .checked_pow(exp as u32)
                    .and_then(|factor| v.checked_mul(factor))?;
                0
            } else {
                (-exp) as usize
            };
            Some((v, scale))
        }
        Err(_) => None,
    }
}
