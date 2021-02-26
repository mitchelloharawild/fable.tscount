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
    model_formula <- rlang::new_formula(
      lhs = NULL,
      rhs = Reduce(function(.x, .y) rlang::call2("+", .x, .y), rlang::enexprs(...))
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
    specials = specials_tscount,
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
