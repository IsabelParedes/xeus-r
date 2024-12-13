local({

  message("AAAA Loading xr kernel resources")

  attach(new.env(), "tools:xeusr", pos = 2L)
  .xeus_env <- as.environment("tools:xeusr")
  assign(".xeus_env", .xeus_env, pos = .xeus_env)
  
  message("AAAA Loading xr kernel resources here to begin with")
  # here <- file.path(
  #   dirname(Sys.which("xr")),
  #   "..", "share", "jupyter", "kernels", "xr", "resources"
  # )

  message("AAAA Current dir", getwd())

  here <- file.path(
    "/embed-env", "share", "jupyter", "kernels", "xr", "resources"
  )

  message("AAAA Loading xr kernel resources from ", here)
  message("BBB list all files here: ", list.files(here))

  files <- setdiff(list.files(here), "setup.R")

  message("AAAA Loading xr kernel resources files: ", files)

  for (f in files) {
    file_path <- file.path(here, f)
    message("CCC Loading file: ", file_path)
    sys.source(file_path, envir = .xeus_env)
  }

})
