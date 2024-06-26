use polars::prelude::*;

use crate::RbExpr;

impl RbExpr {
    pub fn array_max(&self) -> Self {
        self.inner.clone().arr().max().into()
    }

    pub fn array_min(&self) -> Self {
        self.inner.clone().arr().min().into()
    }

    pub fn array_sum(&self) -> Self {
        self.inner.clone().arr().sum().into()
    }

    pub fn arr_unique(&self, maintain_order: bool) -> Self {
        if maintain_order {
            self.inner.clone().arr().unique_stable().into()
        } else {
            self.inner.clone().arr().unique().into()
        }
    }

    pub fn arr_to_list(&self) -> Self {
        self.inner.clone().arr().to_list().into()
    }

    pub fn arr_all(&self) -> Self {
        self.inner.clone().arr().all().into()
    }

    pub fn arr_any(&self) -> Self {
        self.inner.clone().arr().any().into()
    }

    pub fn arr_sort(&self, descending: bool, nulls_last: bool) -> Self {
        self.inner
            .clone()
            .arr()
            .sort(SortOptions {
                descending,
                nulls_last,
                ..Default::default()
            })
            .into()
    }

    pub fn arr_reverse(&self) -> Self {
        self.inner.clone().arr().reverse().into()
    }

    pub fn arr_arg_min(&self) -> Self {
        self.inner.clone().arr().arg_min().into()
    }

    pub fn arr_arg_max(&self) -> Self {
        self.inner.clone().arr().arg_max().into()
    }

    pub fn arr_get(&self, index: &RbExpr, null_on_oob: bool) -> Self {
        self.inner
            .clone()
            .arr()
            .get(index.inner.clone(), null_on_oob)
            .into()
    }

    pub fn arr_join(&self, separator: &RbExpr, ignore_nulls: bool) -> Self {
        self.inner
            .clone()
            .arr()
            .join(separator.inner.clone(), ignore_nulls)
            .into()
    }

    pub fn arr_contains(&self, other: &RbExpr) -> Self {
        self.inner
            .clone()
            .arr()
            .contains(other.inner.clone())
            .into()
    }

    pub fn arr_count_matches(&self, expr: &RbExpr) -> Self {
        self.inner
            .clone()
            .arr()
            .count_matches(expr.inner.clone())
            .into()
    }
}
