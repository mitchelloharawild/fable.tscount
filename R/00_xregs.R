globalVariables(c("self", "origin"))

trend <- function(x, knots = NULL, origin = NULL) {
  UseMethod("trend")
}

trend.tbl_ts <- function(x, knots = NULL, origin = NULL) {
  idx_num <- as.double(x[[index_var(x)]])
  knots_num <- if (is.null(knots)) {
    NULL
  } else {
    as.double(knots)
  }
  index_interval <- default_time_units(tsibble::interval(x))
  idx_num <- idx_num / index_interval
  knots_num <- knots_num / index_interval
  if (!is.null(origin)) {
    origin <- as.double(origin) / index_interval
  }

  trend(idx_num, knots_num, origin)
}

trend.numeric <- function(x, knots = NULL, origin = NULL) {
  if (!is.null(origin)) {
    origin <- origin - 1 # trend should count from 1
    x <- x - origin
    knots <- knots - origin
  }
  knots_exprs <- map(knots, function(.x) pmax(0, x - .x))
  knots_exprs <- set_names(
    knots_exprs,
    map_chr(knots, function(.x) paste0("trend_", format(.x)))
  )
  tibble(
    trend = x,
    !!!knots_exprs
  )
}

season <- function(x, period) {
  UseMethod("season")
}

season.tbl_ts <- function(x, period) {
  idx_num <- as.double(x[[index_var(x)]])
  index_interval <- default_time_units(tsibble::interval(x))
  idx_num <- idx_num / index_interval
  period <- get_frequencies(period, x, .auto = "smallest")

  season(idx_num, period)
}

season.numeric <- function(x, period) {
  season_exprs <- map(period, function(.x) expr(factor(floor((x %% (!!.x)) + 1), levels = seq_len(!!.x))))
  season_exprs <- set_names(season_exprs, names(period) %||% paste0("season_", period))
  tibble(!!!season_exprs)
}

fourier <- function(x, period, K, origin = NULL) {
  UseMethod("fourier")
}

fourier.tbl_ts <- function(x, period, K, origin = NULL) {
  idx_num <- as.double(x[[index_var(x)]])
  index_interval <- default_time_units(tsibble::interval(x))
  idx_num <- idx_num / index_interval
  if (!is.null(origin)) {
    origin <- as.double(origin) / index_interval
  }
  period <- get_frequencies(period, x, .auto = "smallest")

  fourier(idx_num, period, K, origin)
}

fourier.numeric <- function(x, period, K, origin = NULL) {
  if (length(period) != length(K)) {
    abort("Number of periods does not match number of orders")
  }
  if (any(2 * K > period)) {
    abort("K must be not be greater than period/2")
  }

  fourier_exprs <- map2(
    as.numeric(period), K,
    function(period, K) {
      set_names(seq_len(K) / period, paste0(seq_len(K), "_", round(period)))
    }
  ) %>%
    invoke(c, .) %>%
    .[!duplicated(.)] %>%
    map2(., names(.), function(p, name) {
      out <- exprs(C = cospi(2 * !!p * x))
      if (abs(2 * p - round(2 * p)) > .Machine$double.eps) {
        out <- c(out, exprs(S = sinpi(2 * !!p * x)))
      }
      names(out) <- paste0(names(out), name)
      out
    }) %>%
    set_names(NULL) %>%
    unlist(recursive = FALSE)

  tibble(!!!fourier_exprs)
}

common_xregs <- list(
  trend = function(knots = NULL, origin = NULL) {
    if (is.null(origin)) {
      if (is.null(self$origin)) {
        self$origin <- self$data[[index_var(self$data)]][[1]]
      }
      origin <- self$origin
    }
    as.matrix(fable.tscount:::trend(self$data, knots, origin))
  },
  season = function(period = NULL) {
    as_model_matrix(fable.tscount:::season(self$data, period))
  },
  fourier = function(period = NULL, K, origin = NULL) {
    if (is.null(origin)) {
      if (is.null(self$origin)) {
        self$origin <- self$data[[index_var(self$data)]][[1]]
      }
      origin <- self$origin
    }
    as.matrix(fable.tscount:::fourier(self$data, period, K, origin))
  }
)

as_model_matrix <- function(tbl) {
  stats::model.matrix(~., data = tbl)[, -1, drop = FALSE]
}
