train_tscount <- function(.data, specials, ...) {
  if(length(tsibble::measured_vars(.data)) > 1){
    abort("Only univariate responses are supported by tscount::tsglm()")
  }
  xreg <- specials$xreg[[1]]
  y <- unclass(.data)[[tsibble::measured_vars(.data)]]
  add_class(tscount::tsglm(y, xreg = xreg, ...), class = "fable_tscount")
}

specials_tscount <- new_specials(
  common_xregs,
  xreg = function(...) {
    model_formula <- new_formula(
      lhs = NULL,
      rhs = Reduce(function(.x, .y) call2("+", .x, .y), enexprs(...))
    )
    env <- parent.frame()
    if (!exists("list", env)) env <- base_env()

    env$lag <- lag # Mask user defined lag to retain history when forecasting
    xreg <- model.frame(model_formula, data = env, na.action = stats::na.pass)
    mm <- model.matrix(terms(xreg), xreg)
    mm <- mm[,setdiff(colnames(mm), "(Intercept)"),drop = FALSE]
    if(NCOL(mm) == 0) return(NULL)
    mm
  },
  .required_specials = "xreg",
  .xreg_specials = names(common_xregs),
)

#' @export
#' @importFrom rlang enquo
TSCOUNT <- function(formula, ...) {
  tscount_model <- new_model_class(
    "TSCOUNT",
    train = train_tscount,
    specials = specials_tscount, origin = NULL,
    check = all_tsbl_checks
  )
  new_model_definition(tscount_model, !!enquo(formula), ...)
}

#' @export
model_sum.fable_tscount <- function(x) {
  "TSCOUNT"
}

#' @export
report.fable_tscount <- function(x) {
  cat(capture.output(print(summary(x)))[-c(1:3)], sep = "\n")
}

#' @export
residuals.fable_tscount <- function(x, type = c("innovation", "response", "pearson", "anscombe"), ...) {
  type <- match.arg(type)
  if(type == "innovation") type <- "response"
  NextMethod()
}

#' @export
generate.fable_tscount <- function(x, new_data, specials, ...) {
  xreg <- specials$xreg[[1]]
  tscount_sim <- function(times, xreg) {
    as.numeric(tscount::tsglm.sim(times, fit = x, xreg = xreg, n_start = 0)$ts)
  }
  li <- tsibble::key_data(new_data)[[".rows"]]
  sim <- lapply(li, function(i) tscount_sim(length(i), xreg[i,]))
  new_data[[".sim"]] <- do.call(c, sim)
  new_data
}

#' @export
forecast.fable_tscount <- function(x, new_data, specials, times = 1000, ...) {
  xreg <- specials$xreg[[1]]
  distributional::dist_degenerate(
    predict(x, n.ahead = nrow(new_data), newxreg = xreg, level = .8,
            B = times)$pred
  )
}
