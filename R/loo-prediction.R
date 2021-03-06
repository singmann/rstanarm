#' Compute weighted expectations using LOO
#' 
#' These functions are wrappers around the \code{\link[loo]{E_loo}} function 
#' (\pkg{loo} package).
#' 
#' @export
#' @aliases loo_predict loo_linpred loo_predictive_interval
#' 
#' @templateVar stanregArg object
#' @template args-stanreg-object
#' @param lw An optional matrix of (smoothed) log-weights. If \code{lw} is 
#'   missing then \code{\link[loo]{psislw}} is executed internally, which may be
#'   time consuming for models fit to very large datasets.
#' @param ... Optional arguments passed to \code{\link[loo]{psislw}}. If 
#'   \code{lw} is specified these arguments are ignored.
#' @inheritParams loo::E_loo
#'   
#' @return \code{loo_predict} and \code{loo_linpred} return a vector with one 
#'   element per observation. The only exception is if \code{type="quantile"} 
#'   and \code{length(probs) >= 2}, in which case a separate vector for each 
#'   element of \code{probs} is computed and they are returned in a matrix with 
#'   \code{length(probs)} rows and one column per observation.
#'   
#'   \code{loo_predictive_interval} returns a matrix with one row per 
#'   observation and two columns (like \code{\link{predictive_interval}}). 
#'   \code{loo_predictive_interval(..., prob = p)} is equivalent to 
#'   \code{loo_predict(..., type = "quantile", probs = c(a, 1-a))} with 
#'   \code{a = (1 - p)/2}, except it transposes the result and adds informative 
#'   column names.
#'   
#' @examples
#' \dontrun{
#' if (!exists("example_model")) example(example_model)
#' head(loo_predictive_interval(example_model, prob = 0.8, cores = 2))
#' 
#' # optionally, log-weights can be pre-computed and reused
#' psis <- loo::psislw(-log_lik(example_model), cores = 2)
#' loo_predictive_interval(example_model, prob = 0.8, lw = psis$lw_smooth)
#' loo_predict(example_model, type = "var", lw = psis$lw_smooth)
#' }
#' 
loo_predict.stanreg <-
  function(object, 
           type = c("mean", "var", "quantile"), 
           probs = 0.5,
           ...,
           lw) {
    
    type <- match.arg(type)
    lwts <- loo_weights(object, lw, log = TRUE, ...)
    preds <- posterior_predict(object)
    if (is_polr(object) && !is_scobit(object))
      preds <- polr_yrep_to_numeric(preds)
    
    loo::E_loo(
      x = preds,
      lw = lwts,
      type = type,
      probs = probs
    )
  }

#' @rdname loo_predict.stanreg
#' @export
#' @param transform Passed to \code{\link{posterior_linpred}}.
#'    
loo_linpred.stanreg <-
  function(object,
           type = c("mean", "var", "quantile"),
           probs = 0.5,
           transform = FALSE,
           ..., 
           lw) {
    
    type <- match.arg(type)
    lwts <- loo_weights(object, lw, log = TRUE, ...)
    linpreds <- posterior_linpred(object, transform = transform)
    
    loo::E_loo(
      x = linpreds,
      lw = lwts,
      type = type,
      probs = probs
    )
  }


#' @rdname loo_predict.stanreg
#' @export
#' @param prob For \code{loo_predictive_interval}, a scalar in \eqn{(0,1)}
#'   indicating the desired probability mass to include in the intervals. The
#'   default is \code{prob=0.9} (\eqn{90}\% intervals).
loo_predictive_interval.stanreg <- function(object, prob = 0.9, ..., lw) {
  stopifnot(length(prob) == 1)
  alpha <- (1 - prob) / 2
  probs <- c(alpha, 1 - alpha)
  labs <- paste0(100 * probs, "%")
  intervals <-
    loo_predict.stanreg(object,
                        type = "quantile",
                        probs = probs,
                        lw = lw, 
                        ...)
  rownames(intervals) <- labs
  t(intervals)
}

# internal ----------------------------------------------------------------

# @param object,lw,... Same as above.
# @param log If FALSE (default) the weights are exponentiated before returning
# @return A matrix.
loo_weights <- function(object, lw, log = FALSE, ...) {
  if (!missing(lw)) {
    stopifnot(is.matrix(lw))
  } else {
    message("Running PSIS to compute weights...")
    psis <- loo::psislw(llfun = ll_fun(object), llargs = ll_args(object), ...)
    lw <- psis[["lw_smooth"]]
  }
  if (log) 
    return(lw) 
  
  exp(lw)
}
