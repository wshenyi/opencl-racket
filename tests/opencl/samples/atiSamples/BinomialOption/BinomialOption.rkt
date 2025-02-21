#lang racket
(require opencl/c
         "../atiUtils/utils.rkt"
         ffi/unsafe
         ffi/cvector
         ffi/unsafe/cvector)

(define RISKFREE 0.02)
(define VOLATILITY 0.30)
(define setupTime -1)
(define totalKernelTime -1)
(define devices #f)
(define context #f)
(define commandQueue #f)
(define program #f)
(define kernel #f)
(define randArray #f)
(define output #f)
(define randBuffer #f)
(define outBuffer #f)
(define numSamples 1024)
(define numSteps 0)

(define (setupBinomialOption)
  (set! randArray (malloc (* numSamples (ctype-sizeof _cl_float4)) 'raw))
  (for ([i (in-range (* 4 numSamples))])
    (ptr-set! randArray _cl_float i (random)))
  (set! output (malloc (* numSamples (ctype-sizeof _cl_float4)) 'raw))
  (memset output 0 (* numSamples (ctype-sizeof _cl_float4))))

(define (setupCL)
  (set!-values (devices context commandQueue program) (init-cl "BinomialOption_Kernels.cl" #:queueProperties 'CL_QUEUE_PROFILING_ENABLE))
  (set! randBuffer (clCreateBuffer context '(CL_MEM_READ_ONLY CL_MEM_USE_HOST_PTR) (* (ctype-sizeof _cl_float4) numSamples) randArray))
  (set! outBuffer (clCreateBuffer context '(CL_MEM_WRITE_ONLY CL_MEM_USE_HOST_PTR) (* (ctype-sizeof _cl_float4) numSamples) output))
  (set! kernel (clCreateKernel program #"binomial_options"))
  (set! numSteps (- (optimum-threads kernel (cvector-ref devices 0) 256) 2)))

(define (runCLKernels)
  (clSetKernelArg:_cl_int kernel 0 numSteps)
  (clSetKernelArg:_cl_mem kernel 1 randBuffer)
  (clSetKernelArg:_cl_mem kernel 2 outBuffer)
  (clSetKernelArg:local kernel 3 (* (add1 numSteps) (ctype-sizeof _cl_float4)))
  (clSetKernelArg:local kernel 4 (* numSteps (ctype-sizeof _cl_float4)))
  (define globalThreads (* numSamples (add1 numSteps)))
  (define localThreads (add1 numSteps))
  (clEnqueueNDRangeKernel commandQueue kernel 1 (vector globalThreads) (vector localThreads) (make-vector 0))
  (clFinish commandQueue)
  (clEnqueueReadBuffer commandQueue outBuffer 'CL_TRUE 0 (* numSamples (ctype-sizeof _cl_float4)) output (make-vector 0)))

(define (binomialOptionCPUReference)
  (define refOutput (malloc (* numSamples (ctype-sizeof _cl_float4))))
  (define stepsArray (make-vector (* (add1 numSteps) 4)))
  (for ([bid (in-range numSamples)])
    (define s (make-vector 4))
    (define x (make-vector 4))
    (define vsdt (make-vector 4))
    (define puByr (make-vector 4))
    (define pdByr (make-vector 4))
    (define optionYears (make-vector 4))
    (define inRand (make-vector 4))
    (for ([i (in-range 4)])
      (vector-set! inRand i (ptr-ref randArray _cl_float (+ bid i)))
      (define val (vector-ref inRand i))
      (vector-set! s i (+ (* (- 1.0 val) 5.0) (* val 30.0)))
      (vector-set! x i (+ (* (- 1.0 val) 1.0) (* val 100.0)))
      (vector-set! optionYears i (+ (* (- 1.0 val) 0.25) (* val 10.0)))
      (define dt (* (vector-ref optionYears i) (/ 1.0 numSteps)))
      (vector-set! vsdt i (* VOLATILITY (sqrt dt)))
      (define rdt (* RISKFREE dt))
      (define r (exp rdt))
      (define rInv (/ 1.0 r))
      (define u (exp (vector-ref vsdt i)))
      (define d (/ 1.0 u))
      (define pu (/ (- r d) (- u d)))
      (define pd (- 1.0 pu))
      (vector-set! puByr i (* pu rInv))
      (vector-set! pdByr i (* pd rInv)))
    (for ([j (in-range (add1 numSteps))])
      (for ([i (in-range 4)])
        (define profit (- (* (vector-ref s i) (exp (* (vector-ref vsdt i) (- (* 2.0 j) numSteps)))) (vector-ref x i)))
        (vector-set! stepsArray (+ i (* j 4)) (if (> profit 0.0) profit 0.0))))
    (for ([j (in-range numSteps 0 -1)])
      (for ([k (in-range j)])
        (for ([i (in-range 4)])
          (vector-set! stepsArray (+ i (* k 4)) (+ (* (vector-ref pdByr i) (vector-ref stepsArray (+ i (* 4 (add1 k)))))
                                                    (* (vector-ref puByr i) (vector-ref stepsArray (+ i (* k 4)))))))))
    (ptr-set! refOutput _cl_float bid (vector-ref stepsArray 0)))
  (compare output refOutput numSamples))
  
      
(define (setup)
  (setupBinomialOption)
  (set! setupTime (time-real setupCL)))

(define (run)
  (set! totalKernelTime (time-real runCLKernels)))

(define (verify-results)
  (define verified (binomialOptionCPUReference))
  (printf "~n~a~n" (if verified "Passed" "Failed")))

(define (cleanup)
  (clReleaseKernel kernel)
  (clReleaseProgram program)
  (clReleaseMemObject randBuffer)
  (clReleaseMemObject outBuffer)
  (clReleaseCommandQueue commandQueue)
  (clReleaseContext context)
  (free randArray)
  (free output))

(define (print-stats)
  (printf "~nOption Samples: ~a, Setup Time: ~a, Kernel Time: ~a, Total Time: ~a, Options/sec: ~a~n"
          numSamples 
          (real->decimal-string setupTime 3) 
          (real->decimal-string totalKernelTime 3)
          (real->decimal-string (+ setupTime totalKernelTime) 3)
          (real->decimal-string (/ numSamples (+ setupTime totalKernelTime)))))

(setup)
(run)
(verify-results)
(cleanup)
(print-stats)