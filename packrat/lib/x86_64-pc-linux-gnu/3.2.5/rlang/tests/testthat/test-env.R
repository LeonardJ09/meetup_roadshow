context("environments")

test_that("env() returns current frame by default", {
  fn <- function() expect_identical(env(), environment())
  fn()
})

test_that("env_parent() returns enclosure frame by default", {
  enclos_env <- child_env(pkg_env("rlang"))
  fn <- with_env(enclos_env, function() env_parent())
  expect_identical(fn(), enclos_env)
})

test_that("child_env() has correct parent", {
  env <- child_env(empty_env())
  expect_false(env_has(env, "list", inherit = TRUE))

  fn <- function() list(new = child_env(env()), env = environment())
  out <- fn()
  expect_identical(env_parent(out$new), out$env)

  expect_identical(env_parent(child_env()), empty_env())
  expect_identical(env_parent(child_env("base")), base_env())
})

test_that("env_parent() reports correct parent", {
  env <- child_env(
    child_env(empty_env(), list(obj = "b")),
    list(obj = "a")
  )

  expect_identical(env_parent(env, 1)$obj, "b")
  expect_identical(env_parent(env, 2), empty_env())
  expect_identical(env_parent(env, 3), empty_env())
})

test_that("env_tail() climbs env chain", {
  expect_identical(env_tail(global_env()), base_env())
})

test_that("promises are created", {
  env <- child_env()

  env_assign_promise(env, "foo", bar <- "bar")
  expect_false(env_has(env(), "bar"))

  force(env$foo)
  expect_true(env_has(env(), "bar"))

  f <- ~stop("forced")
  env_assign_promise_(env, "stop", f)
  expect_error(env$stop, "forced")
})

test_that("lazies are evaluated in correct environment", {
  env <- child_env("base")

  env_assign_promise(env, "test_captured", test_captured <- letters)
  env_assign_promise_(env, "test_expr", quote(test_expr <- LETTERS))
  env_assign_promise_(env, "test_formula", ~ (test_formula <- mtcars))
  expect_false(any(env_has(env(), c("test_captured", "test_expr", "test_formula"))))

  force(env$test_captured)
  force(env$test_expr)
  force(env$test_formula)
  expect_true(all(env_has(env(), c("test_captured", "test_expr", "test_formula"))))

  expect_equal(test_captured, letters)
  expect_equal(test_expr, LETTERS)
  expect_equal(test_formula, mtcars)
})

test_that("formula env is overridden by eval_env", {
  env <- child_env("base")
  env_assign_promise_(env, "within_env", quote(new_within_env <- "new"), env)
  force(env$within_env)

  expect_false(env_has(env(), "new_within_env"))
  expect_true(env_has(env, "new_within_env"))
  expect_equal(env$new_within_env, "new")
})

test_that("with_env() evaluates within correct environment", {
  fn <- function() {
    g(env())
    "normal return"
  }
  g <- function(env) {
    with_env(env, return("early return"))
  }
  expect_equal(fn(), "early return")
})

test_that("locally() evaluates within correct environment", {
  env <- child_env("rlang")
  local_env <- with_env(env, locally(env()))
  expect_identical(env_parent(local_env), env)
})

test_that("ns_env() returns current namespace", {
  expect_identical(with_env(ns_env("rlang"), ns_env()), env(rlang::env))
})

test_that("ns_imports_env() returns imports env", {
  expect_identical(with_env(ns_env("rlang"), ns_imports_env()), env_parent(env(rlang::env)))
})

test_that("ns_env_name() returns namespace name", {
  expect_identical(with_env(ns_env("base"), ns_env_name()), "base")
  expect_identical(ns_env_name(rlang::env), "rlang")
})

test_that("as_env() dispatches correctly", {
  expect_identical(as_env("base"), base_env())
  expect_false(env_has(as_env(set_names(letters)), "map"))

  expect_identical(as_env(NULL), empty_env())

  expect_true(all(env_has(as_env(mtcars), names(mtcars))))
  expect_identical(env_parent(as_env(mtcars)), empty_env())
  expect_identical(env_parent(as_env(mtcars, base_env())), base_env())
})
