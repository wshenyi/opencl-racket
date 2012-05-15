#lang scribble/doc
@(require scribble/manual
          scribble/basic
          scribble/extract
          planet/scribble
          (for-label ffi/unsafe
                     "../../c/types.rkt"
                     "../../c/4.rkt"
                     "../../c/4-1.rkt"
                     "../../c/4-2.rkt"
                     "../../c/4-3.rkt"))

@title[#:tag "4" #:style 'toc]{The OpenCL Platform Layer}

@defmodule/this-package[c/4]

@local-table-of-contents[]

@section[#:tag "4.1"]{Querying Platform Info}
@defmodule/this-package[c/4-1]
@include-extracted["../../c/4-1.rkt"]

@section[#:tag "4.2"]{Querying Devices}
@defmodule/this-package[c/4-2]
@include-extracted["../../c/4-2.rkt"]

@section[#:tag "4.3"]{Contexts}
@defmodule/this-package[c/4-3]
@include-extracted["../../c/4-3.rkt"]
