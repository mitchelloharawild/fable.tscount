add_class <- function(x, class) {
  `class<-`(x, c(class, class(x)))
}
