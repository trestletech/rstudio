#
# SessionCodeTools.R
#
# Copyright (C) 2009-12 by RStudio, Inc.
#
# Unless you have received this program directly from RStudio pursuant
# to the terms of a commercial license agreement with RStudio, then
# this program is licensed to you under the terms of version 3 of the
# GNU Affero General Public License. This program is distributed WITHOUT
# ANY EXPRESS OR IMPLIED WARRANTY, INCLUDING THOSE OF NON-INFRINGEMENT,
# MERCHANTABILITY OR FITNESS FOR A PARTICULAR PURPOSE. Please refer to the
# AGPL (http://www.gnu.org/licenses/agpl-3.0.txt) for more details.
#
#

.rs.addFunction("withTimeLimit", function(time,
                                          expr,
                                          envir = parent.frame(),
                                          fail = NULL)
{
   setTimeLimit(elapsed = time, transient = TRUE)
   on.exit(setTimeLimit(), add = TRUE)
   tryCatch(
      eval(expr, envir = envir),
      error = function(e) {
         fail
      }
   )
})

.rs.addFunction("startsWith", function(strings, string)
{
   if (!length(string))
      string <- ""
   
   n <- nchar(string)
   (nchar(strings) >= n) & (substring(strings, 1, n) == string)
})

.rs.addFunction("selectStartsWith", function(strings, string)
{
   strings[.rs.startsWith(strings, string)]
})

.rs.addFunction("endsWith", function(strings, string)
{
   if (!length(string))
      string <- ""
   
   nstrings <- nchar(strings)
   nstring <- nchar(string)
   (nstrings >= nstring) & 
      (substring(strings, nstrings - nstring + 1, nstrings) == string)
})

.rs.addFunction("selectEndsWith", function(strings, string)
{
   strings[.rs.endsWith(strings, string)]
})

# Return the scope names in which the given names exist
.rs.addFunction("which", function(names) {
   scopes = search()
   sapply(names, function(name) {
      for (scope in scopes) {
         if (exists(name, where=scope, inherits=F))
            return(scope)
      }
      return("")
   })
})

.rs.addFunction("guessToken", function(line, cursorPos)
{
   utils:::.assignLinebuffer(line)
   utils:::.assignEnd(cursorPos)
   utils:::.guessTokenFromLine()
})

.rs.addFunction("findFunctionNamespace", function(name, fromWhere)
{
   if (!identical(fromWhere, ""))
   {
      if ( ! (fromWhere %in% search()) )
         return ("")

      where = as.environment(fromWhere)
   }
   else
   {
      where = globalenv()
   }

   envList <- methods:::findFunction(name, where = where)
   if (length(envList) > 0)
   {
      env <- envList[[1]]
      if (identical(env, baseenv()))
      {
         return ("package:base")
      }
      else if (identical(env, globalenv()))
      {
         return(".GlobalEnv")
      }
      else
      {
         envName = attr(envList[[1]], "name")
         if (!is.null(envName))
            return (envName)
         else
            return ("")
      }
   }
   else
   {
      return ("")
   }
})

.rs.addFunction("getFunction", function(name, namespaceName)
{
   tryCatch(eval(parse(text = name),
                 envir = as.environment(namespaceName),
                 enclos = NULL),
            error = function(e) NULL)
})


.rs.addFunction("functionHasSrcRef", function(func)
{
   return (!is.null(attr(func, "srcref")))
})

.rs.addFunction("deparseFunction", function(func, useSource)
{
   control <- c("keepInteger", "keepNA")
   if (useSource)
     control <- append(control, "useSource")

   deparse(func, width.cutoff = 59, control = control)
})

.rs.addFunction("isS3Generic", function(object)
{
   if (!is.function(object))
      return(FALSE)
   
   if (inherits(object, "groupGenericFunction"))
      return(TRUE)
   
   .rs.callsUseMethod(body(object))
   
})

.rs.addFunction("callsUseMethod", function(x)
{
   if (missing(x))
      return(FALSE)
   
   if (!is.call(x))
      return(FALSE)
   
   if (identical(x[[1]], quote(UseMethod)))
      return(TRUE)
   
   if (length(x) == 1)
      return(FALSE)
   
   for (arg in as.list(x[-1]))
      if (.rs.callsUseMethod(arg))
         return(TRUE)
   
   FALSE
})

.rs.addFunction("getS3MethodsForFunction", function(func, envir = parent.frame())
{
  tryCatch({
     call <- call("methods", func)
     as.character(suppressWarnings(eval(call, envir = envir)))
  }, error = function(e) character())
})


# Return a list of S4 methods formatted as  functionName {className, className}
# NOTE: should call isGeneric prior to calling this (it will yield an error
# for functions that aren't generic)
.rs.addFunction("getS4MethodsForFunction", function(func)
{
  sigs <- findMethodSignatures(methods = findMethods(func))
  apply(sigs, 
        1, 
        function(sig)
        {
           paste(func, 
                 " {", 
                 paste(sig, collapse=", "),
                 "}",
                 sep="",
                 collapse = "")
        })
})

.rs.addFunction("getS4MethodNamespaceName", function(method)
{
  env <- environment(method)
  if (identical(env, baseenv()))
    return ("package:base")
  else if (identical(env, globalenv()))
    return (".GlobalEnv")
  else
  {
    envName <- environmentName(env)
    if (envName %in% search())
      return (envName)
    else
      paste("package:", envName, sep="")
  }
})

.rs.addFunction("getPendingInput", function()
{
   .Call("rs_getPendingInput")
})

.rs.addFunction("doStripSurrounding", function(string, complements)
{
   result <- gsub("^\\s*([`'\"])(.*?)\\1.*", "\\2", string, perl = TRUE)
   for (item in complements)
   {
      result <- sub(
         paste("^\\", item[[1]], "(.*)\\", item[[2]], "$", sep = ""),
         "\\1",
         result,
         perl = TRUE
      )
   }
   result
   
})

.rs.addFunction("stripSurrounding", function(string)
{
   complements <- list(
      c("(", ")"),
      c("{", "}"),
      c("[", "]"),
      c("<", ">")
   )
   
   result <- .rs.doStripSurrounding(string, complements)
   while (result != string)
   {
      string <- result
      result <- .rs.doStripSurrounding(string, complements)
   }
   result
})

.rs.addFunction("resolveObjectSource", function(object, envir)
{
   # Try to find the associated namespace of the object
   namespace <- NULL
   if (is.primitive(object))
      namespace <- "base"
   else if (is.function(object))
   {
      envString <- capture.output(environment(object))[1]
      match <- regexpr("<environment: namespace:(.*)>", envString, perl = TRUE)
      if (match == -1L)
         return()
      
      start <- attr(match, "capture.start")[1]
      end <- start + attr(match, "capture.length")[1]
      namespace <- substring(envString, start, end - 1)
   }
   else if (isS4(object))
      namespace <- attr(class(object), "package")
   
   if (is.null(namespace))
      return()
   
   # Get objects from that namespace
   ns <- asNamespace(namespace)
   objectNames <- objects(ns, all.names = TRUE)
   objects <- tryCatch(
      mget(objectNames, envir = ns),
      error = function(e) NULL
   )
   
   if (is.null(objects))
      return()
   
   # Find which object is actually identical to the one we have
   success <- FALSE
   for (i in seq_along(objects))
   {
      if (identical(object, objects[[i]], ignore.environment = TRUE))
      {
         success <- TRUE
         break
      }
   }
   
   # Use that name for the help lookup
   if (success)
      return(list(
         name = objectNames[[i]],
         package = namespace
      ))
   
})

.rs.addFunction("getAnywhere", function(name, envir = parent.frame())
{
   result <- NULL
   
   if (!length(name))
      return(NULL)
   
   if (is.character(name) && (length(name) != 1 || name == ""))
      return(NULL)
   
   # Don't evaluate any functions -- blacklist any 'name' that contains a paren
   if (is.character(name) && regexpr("(", name, fixed = TRUE) > 0)
      return(FALSE)
   
   if (is.character(name) && is.character(envir))
   {
      # If envir is the name of something on the search path, get it from there
      pos <- match(envir, search(), nomatch = -1L)
      if (pos >= 0)
      {
         object <- tryCatch(
            get(name, pos = pos),
            error = function(e) NULL
         )
         
         if (!is.null(object))
            return(object)
      }
      
      # Otherwise, maybe envir is the name of a package -- search there
      if (envir %in% loadedNamespaces())
      {
         object <- tryCatch(
            get(name, envir = asNamespace(envir)),
            error = function(e) NULL
         )
         
         if (!is.null(object))
            return(object)
      }
   }
   
   if (is.character(name))
   {
      name <- .rs.stripSurrounding(name)
      name <- tryCatch(
         suppressWarnings(parse(text = name)),
         error = function(e) NULL
      )
      
      if (is.null(name))
         return(NULL)
   }
   
   if (is.language(name))
   {
      result <- tryCatch(
         eval(name, envir = envir),
         error = function(e) NULL
      )
   }
   
   result
})

.rs.addFunction("getFunctionArgumentNames", function(object)
{
   if (is.primitive(object))
   {
      ## Only closures have formals, not primitive functions.
      result <- tryCatch({
         parsed <- suppressWarnings(parse(text = capture.output(print(object)))[[1L]])
         names(parsed[[2]])
      }, error = function(e) {
         character()
      })
   }
   else
   {
      result <- names(formals(object))
   }
   result
})

.rs.addFunction("getNames", function(object)
{
   if (is.environment(object))
      ls(object, all.names = TRUE)
   else if (inherits(object, "tbl") && "dplyr" %in% loadedNamespaces())
      dplyr::tbl_vars(object)
   else
      names(object)
})

.rs.addJsonRpcHandler("get_help_at_cursor", function(line, cursorPos)
{
   token <- .rs.guessToken(line, cursorPos)
   if (token == '')
      return()

   pieces <- strsplit(token, ':{2,3}')[[1]]

   if (length(pieces) > 1)
      print(help(pieces[2], package=pieces[1], help_type='html'))
   else
      print(help(pieces[1], help_type='html', try.all.packages=T))
})

.rs.addJsonRpcHandler("is_function", function(nameString, envString)
{
   object <- NULL
   
   if (envString == "")
   {
      object <- .rs.getAnywhere(nameString, parent.frame())
   }
   else
   {
      envString <- .rs.stripSurrounding(envString)
      if (envString %in% search())
      {
         object <- tryCatch(
            get(nameString, pos = which(envString == search())),
            error = function(e) NULL
         )
      }
      else if (envString %in% loadedNamespaces())
      {
         object <- tryCatch(
            get(nameString, envir = asNamespace(envString)),
            error = function(e) NULL
         )
      }
      else if (!is.null(container <- .rs.getAnywhere(envString, parent.frame())))
      {
         if (isS4(container))
         {
            object <- tryCatch(
               eval(call("@", container, nameString)),
               error = function(e) NULL
            )
         }
         else
         {
            object <- tryCatch(
               eval(call("$", container, nameString)),
               error = function(e) NULL
            )
         }
      }
   }
   .rs.scalar(!is.null(object) && is.function(object))
})

.rs.addFunction("asCaseInsensitiveRegex", function(string)
{
   if (string == "")
      return(string)
   
   splat <- strsplit(string, "", fixed = TRUE)[[1]]
   lowerSplat <- tolower(splat)
   upperSplat <- toupper(splat)
   result <- vapply(1:length(splat), FUN.VALUE = character(1), USE.NAMES = FALSE, function(i) {
      if (lowerSplat[i] == upperSplat[i])
         splat[i]
      else
         paste("[", lowerSplat[i], upperSplat[i], "]", sep = "")
   })
   paste(result, collapse = "")
})

.rs.addFunction("escapeForRegex", function(regex)
{
   gsub("([\\-\\[\\]\\{\\}\\(\\)\\*\\+\\?\\.\\,\\\\\\^\\$\\|\\#\\s])", "\\\\\\1", regex, perl = TRUE)
})

.rs.addFunction("objectsOnSearchPath", function(token, caseInsensitive = FALSE)
{
   token <- .rs.escapeForRegex(token)
   if (caseInsensitive)
      token <- .rs.asCaseInsensitiveRegex(token)
   
   search <- search()
   objects <- lapply(1:length(search()), function(i) {
      ls(pos = i, all.names = TRUE, pattern = paste("^", token, sep = ""))
   })
   
   names(objects) <- search
   
   objects
})

.rs.addFunction("assign", function(x, value)
{
   pos <- which(search() == "tools:rstudio")
   if (length(pos))
      assign(paste(".rs.cache.", x, sep = ""), value, pos = pos)
})

.rs.addFunction("get", function(x)
{
   pos <- which(search() == "tools:rstudio")
   if (length(pos))
      tryCatch(
         get(paste(".rs.cache.", x, sep = ""), pos = pos),
         error = function(e) NULL
      )
})

.rs.addFunction("mget", function(x = NULL)
{
   pos <- which(search() == "tools:rstudio")
   if (length(pos))
      tryCatch({
         
         objects <- if (is.null(x))
            .rs.selectStartsWith(objects(pos = pos, all.names = TRUE), ".rs.cache")
         else
            paste(".rs.cache.", x, sep = "")
         
         mget(objects, envir = as.environment(pos))
      },
         error = function(e) NULL
      )
})

.rs.addFunction("packageNameForSourceFile", function(filePath)
{
   .Call("rs_packageNameForSourceFile", filePath)
})

.rs.addFunction("isRScriptInPackageBuildTarget", function(filePath)
{
   .Call("rs_isRScriptInPackageBuildTarget", filePath)
})

.rs.addFunction("namedVectorAsList", function(vector)
{
   # Early escape for zero-length vectors
   if (!length(vector))
   {
      return(list(
         values = NULL,
         names = NULL
      ))
   }
   
   values <- unlist(vector, use.names = FALSE)
   vectorNames <- names(vector)
   names <- unlist(lapply(1:length(vector), function(i) {
      rep.int(vectorNames[i], length(vector[[i]]))
   }))
   
   list(values = values,
        names = names)
})

.rs.addFunction("getDollarNamesMethod", function(object)
{
   classes <- class(object)
   for (class in classes)
   {
      method <- .rs.getAnywhere(paste(".DollarNames", class, sep = "."))
      if (!is.null(method))
         return(method)
   }
   NULL
})

.rs.addJsonRpcHandler("get_args", function(name, src)
{
   result <- .rs.getSignature(.rs.getAnywhere(name, src))
   result <- sub("function ", "", result)
   .rs.scalar(result)
})