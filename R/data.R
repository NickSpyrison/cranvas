##' Create a mutaframe from data with attributes for interaction
##'
##' This function will first check if the names of some pre-defined
##' row attributes (e.g. \code{.color}, \code{.brushed}) exist in the
##' column names of the data (will issue an error if they do); then
##' append these columns to the original data to create an augmented
##' data as a \code{\link[plumbr]{mutaframe}}; in the end add some
##' attributes to the mutaframe for the purpose of interaction (mainly
##' the \code{\link{brush}} object and the linking specification). A
##' shadow matrix will be attached if any missing values are present
##' in the original data.
##'
##' When the three arguments \code{color}, \code{border} and
##' \code{size} take values as variable names in \code{data}, default
##' palettes will be used to generate colors and sizes. The sequential
##' color gradient palette (\code{\link[scales]{seq_gradient_pal}})
##' will be applied to continuous variables, and the hue palette
##' (\code{\link[scales]{hue_pal}}) will be applied to categorical
##' variables. The area palette (\code{\link[scales]{area_pal}}) is
##' used to create a size vector when the size variable is
##' continuous. An attribute \code{attr(data, 'Scales')} is attached
##' to the returned mutaframe, which will help specific plots to
##' generate legends. This attribute is of the form \code{list(color =
##' list(title, variable, palette))}. Whenever any component is
##' changed, the corresponding aesthetics will be updated
##' automatically; for example, if we change the palette function for
##' \code{color}, the colors \code{data$.color} will be updated using
##' the new palette. See \code{\link{color_pal<-}} for a list of
##' functions on how to modify scales information.
##'
##' @param data a data frame (it will be coerced to a data frame if it
##' is not)
##' @param color colors of graphical elements (default dark gray)
##' corresponding to rows of data; it can be a vector of valid R
##' colors, or a name of variable in \code{data} (must be either a
##' factor or a numeric variable), or an R expression to calculate
##' colors; \code{color} is used to fill the interior of graphical
##' elements
##' @param border colors for the border of graphical elements
##' (e.g. rectangles); \code{NA} means to suppress the border
##' @param size sizes of rows (default 1); possible values are similar
##' to \code{color}, but when using a variable to generate sizes, it
##' must be a numeric variable
##' @param brushed a logical vector indicating which rows are brushed
##' (default all \code{FALSE})
##' @param visible a logical vector indicating which rows are visible
##' (default all \code{TRUE})
##' @param copy logical: if \code{TRUE}, a copy of the generated data
##' object is stored and can be accessed later by
##' \code{\link{last_data}()}, which enables us to ignore the
##' \code{data} argument in many plotting functions since they default
##' to \code{\link{last_data}()}
##' @return a mutaframe with attributes for interaction
##' @author Yihui Xie <\url{http://yihui.name}>
##' @seealso \code{\link[plumbr]{mutaframe}}, \code{\link{brush}}
##' @note The argument \code{copy} should be used with care. If we
##' only focus on one dataset and all plots are created from this
##' dataset, \code{copy = TRUE} can save some typing efforts. However,
##' if we need to switch between different datasets frequently, it is
##' recommended to write the \code{data} argument in a plotting
##' function explicitly, e.g. \code{qbar(x, data =
##' a_specific_data_object)}.
##' @export
##' @example inst/examples/qdata-ex.R
qdata =
    function(data, color = "gray15", border = color, size = 4,
             brushed = FALSE, visible = TRUE, copy = TRUE) {
    if (!is.data.frame(data))
        data = as.data.frame(data)
    ## check if the attribute exists
    ## row attributes needed by all plotting functions
    row_attrs = c(".color", ".border", ".size", ".brushed", ".visible")
    ## once in a blue moon...
    conflict_attrs = row_attrs %in% colnames(data)
    if (any(conflict_attrs)) {
        stop(sprintf("variable names conflicts: %s already exist(s) in data",
                     paste(row_attrs[conflict_attrs], collapse = ", ")))
    }
    mf = data
    mf$.brushed = brushed
    mf$.visible = visible

    z = as.list(match.call()[-1])
    l = Scales.meta$new()  # record scales in an environment genreated by ref classes
    for (i in c('color', 'border', 'size')) {
        if (is.language(z[[i]])) {
            v = eval(z[[i]], data)
            pal = NULL
            mf[[sprintf('.%s', i)]] = if (i != 'size') {
                if (is.factor(v)) {
                    pal = hue_pal()
                    dscale(v, pal)
                } else if (is.numeric(v)) {
                    pal = seq_gradient_pal()
                    cscale(v, pal)
                } else {
                    if (!inherits(try(col2rgb(v), silent = TRUE), 'try-error')) v else
                    stop(sQuote(i),
                         ' must be either a factor or a numeric variable or valid colors!')
                }
            } else if (is.numeric(v)) {
                pal = (function(range = c(1, 6)) {
                    function(x) scales::rescale(x, range, range(x, na.rm = TRUE))
                })()
                pal(v)
            } else stop(sQuote('size'), ' must be numeric!')
            l[[i]] =
                list(title = deparse(z[[i]]), variable = deparse(z[[i]]),
                     palette = pal)
        } else {
            if ((i == 'border') && is.null(z[[i]])) mf$.border = mf$.color else
            mf[[sprintf('.%s', i)]] = switch(i, color = color, border = border, size = size)
        }
    }

    ## prevent converting from characters to factors
    if (!is.mutaframe(mf)) {
        old_opts = options(stringsAsFactors = FALSE)
        mf = as.mutaframe(mf)
        on.exit(options(old_opts))
    }

    ## attach a brush to data; we need to create the xxxChanged event in specific plots
    ## use brush(data) to access this brush
    attr(mf, "Brush") =
        brushGen$new(style = list(color = "yellow", linewidth = 2, linetype = NULL),
                     color = "yellow", size = 4,
                     mode = "none", identify = FALSE, label.gen = function(x) {
                         x = t(as.data.frame(x))
                         paste(capture.output(print(x, quote = FALSE)), collapse = '\n')
                     }, label.color = "darkgray",
                     history.size = 30, history.index = 0, history.list = list(),
                     persistent = FALSE, persistent.color = character(0),
                     persistent.list = list(), select.only = FALSE, draw.brush = TRUE,
                     cursor = 0L)

    ## here 'mode' is explained in the documentation of mode_selection()

    attr(mf, "Link") = mutalist(linkid = NULL, linkvar = NULL, type = NULL)

    shadow = is.na(data)  # shadow matrix for missing values
    ## add shadow matrix to 'shadow' attribute
    if (sum(shadow)) {
        idx = (colSums(shadow) > 0)
        message('There are ', sum(shadow),' missing values in ', sum(idx), ' columns.',
                ' A shadow matrix is attached to attr(data, "Shadow")')
        attr(mf, 'Shadow') = shadow
        add_listener(mf, function(i, j) {
            if (is.null(j)) return()
            if (!(j %in% row_attrs))
                attr(mf, 'Shadow') = is.na(as.data.frame(mf[, !(names(mf) %in% row_attrs)]))
        })  # shadow matrix will change when data is changed
    }

    ## whenever the scales information is changed, update data columns
    update_scales = function(comp) {
        if (length(l[[comp]]) && is.function(pal <- l[[comp]]$palette)) {
            if (!((name <- l[[comp]]$variable) %in% names(mf)))
                stop(sprintf('variable \'%s\'is not in the data!'), name)
            v = mf[, name]
            if (comp %in% c('color', 'border')) {
                mf[[sprintf('.%s', comp)]] = if (is.numeric(v))
                    cscale(v, pal) else if (is.factor(v)) dscale(v, pal) else {
                        mf[[sprintf('.%s', comp)]]
                    }
            } else if (comp == 'size') {
                mf$.size = if (is.numeric(v)) pal(v) else mf$.size
            }
        }
    }
    l$colorChanged$connect(function() update_scales('color'))
    l$borderChanged$connect(function() update_scales('border'))
    l$sizeChanged$connect(function() update_scales('size'))

    attr(mf, 'Scales') = l  # scales information to be used in legend
    attr(mf, 'Generator') = 'd38bbe46dae5fa45758f3609f5dc1a0a'  # a token for internal use
    if (copy) .cranvasEnv$.last.data = mf  # make a copy to .last.data
    mf
}
Scales.meta =
    setRefClass("Scales_meta", fields =
                properties(list(color = 'list', border = 'list', size = 'list')))


.cranvasEnv$.last.data = NULL

##' Get the last used data object
##'
##' Since interactive graphics often involves with linking based on
##' the same data object, this function provides an access to the last
##' used data object, which is often the default value for the
##' argument \code{data} in many plotting functions in this package.
##' @return The last data object created by \code{\link{qdata}}.
##' @author Yihui Xie <\url{http://yihui.name}>
##' @export
##' @examples library(cranvas)
##' data(nrcstat)
##' qnrc = qdata(nrcstat, color = RegCode)
##' qbar(RegCode, data = last_data())
##' ## or simply ignore the data argument
##' qbar(RegCode)
last_data = function() {
    if (is.null(.cranvasEnv$.last.data))
        stop('No data object was created by qdata() yet') else .cranvasEnv$.last.data
}


##' Set or query the visibility of observations
##'
##' There is a column \code{.visible} to control the visibility of
##' observations. This can be useful for ``deleting'' certain
##' observations from the plot (set their visibility to \code{FALSE}).
##' @param data the mutaframe
##' @return The function \code{\link{visible}} returns the logical
##' vector to control the visibility of observations
##' @author Yihui Xie <\url{http://yihui.name}>
##' @seealso \code{\link{qdata}}
##' @export
##' @examples df = qdata(iris)
##'
##' visible(df)
##'
##' visible(df) = rep(c(TRUE, FALSE), c(100, 50))  # hide the last 50 obs
##'
##' visible(df)
##'
visible = function(data) {
    data$.visible
}
##' @rdname visible
##' @usage visible(data) <- value
##' @param value a logical vector of the length \code{nrow(data)}
##' @export "visible<-"
`visible<-` = function(data, value) {
    data$.visible = value
    data
}

##' Set or query the selected (brushed) observations
##'
##' The column \code{.brushed} controls which observations are being
##' brushed (i.e. those \code{TRUE}'s are selected).
##' @param data the mutaframe
##' @return The function \code{\link{selected}} returns the logical
##' vector corresponding to whether the observations are selected or
##' not
##' @author Yihui Xie <\url{http://yihui.name}>
##' @seealso \code{\link{qdata}}
##' @export
##' @examples df = qdata(mtcars)
##'
##' selected(df)
##'
##' selected(df) = rep(c(TRUE, FALSE), c(10, 22))  # brush the first 10 obs
##' selected(df)
##'
##' selected(df) = 15L  # brush the 15th row
##' selected(df)
##'
##' selected(df) = 'Honda Civic'  # brush by row names
selected = function(data) {
    if ('.brushed' %in% names(data))
        data$.brushed else logical(nrow(data))
}
##' @rdname selected
##' @usage selected(data) <- value
##' @param value a logical vector of the length \code{nrow(data)}, or
##' a vector of integers which will be used to create a logical vector
##' with \code{TRUE} corresponding to these indicies, or a character
##' vector of row names to brush the corresponding rows
##' @export "selected<-"
`selected<-` = function(data, value) {
    ## if value is numeric indices or names, convert it to a logical vector
    if (is.numeric(value) || is.character(value)) {
        tmp = logical(nrow(data))
        names(tmp) = rownames(data)
        tmp[value] = TRUE
        value = unname(tmp)
    }
    data$.brushed = value
    data
}

##' Set or query the linking variable in a mutaframe
##'
##' @param data the mutaframe (typically created by
##' \code{\link{qdata}}), with an attribute \code{Link}
##' @return \code{\link{link_var}} returns the name of the linking
##' variable
##' @author Yihui Xie <\url{http://yihui.name}>
##' @seealso \code{\link{qdata}}
##' @export
##' @examples
##' mf = qdata(head(iris))
##' link_var(mf)  # NULL
##' link_var(mf) = 'Species'  # linking by 'Species'
##' link_var(mf)
##' link_var(mf) = NULL  # disable linking
link_var = function(data) {
    attr(data, "Link")[["linkvar"]]
}

##' @rdname link_var
##' @usage link_var(data) <- value
##' @param value the name of the linking variable (or \code{NULL} to
##' disable linking); the variable must be a factor (i.e. categorical
##' variable)
##' @export
`link_var<-` = function(data, value) {
    if (!is.null(value)) {
        if (!(value %in% colnames(data)))
            stop(value, " is not in the column names of data")
        if (!is.factor(data[, value]))
            stop('currently only support linking through categorical variables (factors)')
    }
    attr(data, "Link")[["linkvar"]] = value
    data
}

##' Set or query the type of linking
##'
##' Types of linking include hot, cold and self linking. Hot linking
##' means other plots get updated immediately after the current plot
##' is brushed; cold linking will not update other plots until they
##' are on focus; self linking means all the elements in the same
##' category as the current brushed element(s) will be brushed as
##' well.
##'
##' @param data the mutaframe (typically created by
##' \code{\link{qdata}}), with an attribute \code{Link}
##' @return \code{\link{link_type}} returns the type of linking
##' @author Yihui Xie <\url{http://yihui.name}>
##' @export
##' @examples
##' mf = qdata(iris)
##' link_type(mf)
##' link_type(mf) = 'self'
##' link_type(mf) = 'cold'
link_type = function(data) {
    attr(data, 'Link')$type
}
##' @rdname link_type
##' @usage link_type(data) <- value
##' @param value the type of linking (possible values are \code{hot},
##' \code{cold} and \code{self})
##' @export
`link_type<-` = function(data, value) {
    attr(data, 'Link')$type = value
    data
}

##' Check if a data object was created by qdata()
##'
##' Data objects created by \code{\link{qdata}} has a special
##' token. If an object was not created in that way, it can be
##' converted by \code{\link{qdata}}.
##'
##' This function is designed for developers to check the validity of
##' data objects.
##' @param data a data object
##' @param convert whether to convert the input data by
##' \code{\link{qdata}}
##' @return If \code{convert == FALSE}, this function only returns a
##' logical value indicating whether the data object was created by
##' \code{\link{qdata}}, otherwise it will be converted if it was not
##' from \code{qdata(data)}.
##' @author Yihui Xie <\url{http://yihui.name}>
##' @export
##' @examples check_data(cbind(x = 1:5, y = 6:10))
##' check_data(1:8, convert = FALSE); check_data(qdata(mtcars), convert = FALSE)  # TRUE
check_data = function(data, convert = TRUE) {
    is_qdata = identical(attr(data, 'Generator'), 'd38bbe46dae5fa45758f3609f5dc1a0a')
    if (!convert) return(is_qdata)
    if (is_qdata) data else {
        message(paste(strwrap('Automatically converting to a mutaframe... Interaction will work based on this data, but will not link to any other plots. For linking to work, use qdata() to create data objects.'), collapse = '\n'))
        qdata(data)
    }
}


`.data_scales<-` = function(data, node1, node2, value) {
    attr(data, 'Scales')[[node1]][[node2]] <- value
    data
}

##' Set palettes and variables to map data to aesthetics
##'
##' These functions provide ways to modify the palettes, variables to
##' create aesthetics and their titles in a data object created by
##' \code{\link{qdata}}. Currently supported aesthetics are about
##' color, border and size of graphical elements.
##'
##' All these information is called ``scales'' (in the \pkg{ggplot2}
##' term) and stored in \code{attr(data, 'Scales')}. Usually palette
##' functions are from the \pkg{scales} package.
##' @param data the data object
##' @param value the palette (as a function mapping a data variable to
##' graphical properties), the variable name (as a character scalar),
##' or the title (as a character scalar)
##' @return The corresponding scale information in \code{data} is set
##' to \code{value}.
##' @author Yihui Xie <\url{http://yihui.name}>
##' @export
##' @example inst/examples/scales-ex.R
##' @rdname set_scales
##' @usage color_pal(data) <- value
##' @export
`color_pal<-` = function(data, value) {
    .data_scales(data, 'color', 'palette') = value
    data
}
##' @rdname set_scales
##' @usage color_var(data) <- value
##' @export
`color_var<-` = function(data, value) {
    .data_scales(data, 'color', 'variable') = value
    color_title(data) = value  # should change title too when variable is changed
    data
}
##' @rdname set_scales
##' @usage color_title(data) <- value
##' @export
`color_title<-` = function(data, value) {
    .data_scales(data, 'color', 'title') = value
    data
}
##' @rdname set_scales
##' @usage border_pal(data) <- value
##' @export
`border_pal<-` = function(data, value) {
    .data_scales(data, 'border', 'palette') = value
    data
}
##' @rdname set_scales
##' @usage border_var(data) <- value
##' @export
`border_var<-` = function(data, value) {
    .data_scales(data, 'border', 'variable') = value
    border_title(data) = value
    data
}
##' @rdname set_scales
##' @usage border_title(data) <- value
##' @export
`border_title<-` = function(data, value) {
    .data_scales(data, 'border', 'title') = value
    data
}
##' @rdname set_scales
##' @usage size_pal(data) <- value
##' @export
`size_pal<-` = function(data, value) {
    .data_scales(data, 'size', 'palette') = value
    data
}
##' @rdname set_scales
##' @usage size_var(data) <- value
##' @export
`size_var<-` = function(data, value) {
    .data_scales(data, 'size', 'variable') = value
    size_title(data) = value
    data
}
##' @rdname set_scales
##' @usage size_title(data) <- value
##' @export
`size_title<-` = function(data, value) {
    .data_scales(data, 'size', 'title') = value
    data
}
