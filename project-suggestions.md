# Project Suggestions

These projects are intentionally open-ended.  They are intended as an
opportunity for you to showcase your mastery of the learning goals:

* Parallel algorithmic reasoning.

* Parallel cost models.

* Judging the suitability of the language/tool for the problem at
  hand.

* Applied data-parallel programming.

This means that you are free to diverge from the project descriptions
below, or come up with your own ideas, as long as they provide a
context in which you can demonstrate the course contents.

You are *not* judged on whether e.g. Futhark or ISPC or whatever
language you choose happens to be a good fit or run particularly fast
for whatever problem you end up picking, but you *are* judged on how
you evaluate its suitability.

## Porting PBBS benchmarks

The [Problem Based Benchmark
Suite](https://cmuparlay.github.io/pbbsbench/) is a collection of
benchmark programs written in parallel C++. We are interested in
porting them to a high-level parallel language (e.g. Futhark). Some of
the benchmarks are relatively trivial; others are more difficult. It
might be a good idea for a project to combine a trivial benchmark with
a more complex one. The [list of benchmarks is
here](https://cmuparlay.github.io/pbbsbench/benchmarks/index.html).
The ones listed as *Basic Building Blocks* are all pretty
straightforward. Look at the others and pick whatever looks
interesting (but talk to us first - some, e.g. rayCast, involve no
interesting parallelism, and so are not a good DPP project).
Particularly interesting to Troels are the ones related to
computational geometry:

* [delaunayRefine](https://cmuparlay.github.io/pbbsbench/benchmarks/delaunayRefine.html)
* [rangeQuery2d](https://cmuparlay.github.io/pbbsbench/benchmarks/rangeQuery2d.html)

## Batched Rank-k Search

For those that have not chosen this problem in the PMPH course, you are welcome to solve [the rank-k search problem](material/rank-search-k/Project-RankSearch-k.pdf).


## Project Related to Automatic Differentiation

[Minpack-2](material-projects/Mpack-2/Minpack-2.pdf) is a collection
of problems that require computation of derivatives. The
implementation language is Fortran, and each problem implementation
has options for computing the primal (original program), or/and the
associated Jacobian (or even Hessian).

This task refers to porting one (or several) of the Minpack-2
benchmarks to Futhark: you need to translate only "the primal" (i.e.,
the original function that requires differentiation), and then you may
use Futhark's support for automatic differentiation to compute the
dense Jacobian/Hessians.

Many of the Minpack-2 primals result in sparse Jacobians or Hessians
(i.e., the second-order derivative); hence the last step is to
visualize/characterize the sparsity of the differentiated code. [Here
is a paper that shows the sparsity of a several applications from
Minpack-2](material-projects/Mpack-2/Efficient_Computation_of_Gradients_and_Jacobians_b.pdf)

A "project outside the scope" with the same goal, but which did not
reach the visualization goal is available
[here](https://futhark-lang.org/student-projects/peter-msc-project.pdf);
perhaps you will find it useful at least for the Minpack-2 related
information (inside).

Bonus: if time permits, you may try to optimize the computation, e.g.,
by packing in a safe way several unit vectors into a denser
representation that contains several one entries.

## Halide (this project involves some CUDA)

Halide ([paper](https://dl.acm.org/doi/10.1145/2491956.2462176); [github](https://github.com/halide/Halide)) 
is a (famous) domain-specific language (DSL) for expressing and
efficiently executing image-processing pipelines, where the main
optimization is stencil fusion. Halide has popularized the idea
of separating the implementation into (1) a clean/simple 
(functional/data-flow) specification which is accessible to domain
experts and (2) an optimization recipe that is either specified by
the compiler expert or is inferred through extensive autotuning.

This project requires two main tasks: First, you will install and
evaluate several Halide optimization recipes on several benchmarks,
such as for example (1) the blur filter presented in the paper,
(2) overlapped tiling applied to fuse the same 2D stencil of 
radius 1, and (3) maybe overlapped tiling + sliding window within
tiles to fuse the same 3D stencil of radius 1.  
Second, you will try to write some specialized CUDA code that
matches Halide performance on some of these benchmarks.  
 
Your project should contain: 

- a summary of the Halide paper that presents (1) the optimizations space organized on three axes---amount of exploited parallelism, locality, redundant computation---and (2) several of the code transformations (optimization recipes) that navigate this space.

- a characterization of the chosen benchmarks, i.e., how does the tradeoff between redundant computation, parallelism and locality manifests for each of them?

- a systematic evaluation of performance that demonstrates the extent to which each specialization (implementation) utilizes the hardware and compares the performance across different optimization recipes of the same stencil program; this refers both to Halide programs and your CUDA implementation. You should probably use a normalized memory throughput (GB/sec) to measure performance (or the roofline model).

- a presentation of the CUDA code that implements each of the chosen examples/benchmarks, which includes the rationale of how this specialization was obtained and where does it fit in the optimization space.  It is fine for readability to use C-like pseudocode in which you annotate with comments which loops form the grid, which loops form the CUDA block of threads, which loops are sequential, which buffers are allocated in shared memory and which are in global memory (for GPU).

## Vectorised Automatic Differentiation

Vectorised AD is a variant of AD where you have multiple seed values, thus
computing multiple rows (or columns) of the Jacobian simultaneously. It is
completely unrelated to "vectorisation" understood as SIMD execution, or
"vectorisation" as an alias for flattening. Vectorised AD is completely
equivalent to just `map`ing over multiple seed values and using `jvp` or `vjp`
multiple times, but vectorised AD allows the primal to be computed only once. We
have an [experimental implementation of vectorised AD for the Futhark
compiler](https://github.com/diku-dk/futhark/tree/ad-vec), with the following
API:

```Futhark
val jvp_vec 'a 'b [n] : (f: a -> b) -> (x: a) -> (x': [n]a) -> [n]b

val vjp_vec 'a 'b [n] : (f: a -> b) -> (x: a) -> (y': [n]b) -> [n]a
```

How how the seeds are now arrays of size `n`. The implementation is reasonably
complete, although likely still buggy. Two kinds of projects are possible in
this domain. Both are focused on the *implementation* of AD - that is, these are
projects related to compiler implementation.

1. Apply vectorised AD to a problem that is currently solved with non-vectorised
   AD, and investigate the resulting performance. In practice, I have found that
   vectorised AD is often (but not always) slower, which I suspect is because
   arrays show up in undesirable places (e.g. as the operands to reductions).
   This project is about identifying such cases and proposing remedies, either
   new optimisations, or tweaks to the vectorised AD algorithm, such as locally
   disabling vectorisation for some cases. If time permits, these suggestions
   can also be implemented.

2. Implement additional special cases of vectorised AD. There is a bunch of AD
   special cases in particular for reductions, scans, or histograms, and not all
   of these support vectorised AD yet. This project is about adding support in
   whatever way is most efficient - in some cases this may be by locally
   disabling vectorisation.

These projects are most relevant if you dream of doing a later project where you
work on the Futhark compiler itself. We have had several successful DPP projects
that involve compiler hacking, but they are necessarily limited in scope due to
the time available. You should be reasonably comfortable with Haskell if you
pick this project, and be willing to ask for help along the way.

## All Previous Smaller Element Problem

To solve the previous smaller element problem one must find the index
of the first element with a smaller index which satisfies it is
smaller than the current element.  When apply this to all elements we
call this the all previous smaller element problem.  This problem can
be used for finding the parent vector given given the depth vector of
a preorder traversal of a tree as seen in previous assignments.  We
have seen this can be solved in `O(n^2)` work and `O(n)` span using
backwards linear search.  This problem can be improved by using
sorting or a binary tree of minima [1] to get `O(n log n)` work and
`O(log n)` span (found
[here](https://github.com/diku-dk/containers/blob/main/lib/github.com/diku-dk/containers/reduction_tree.fut)
the original paper has a version with better complexity [1]).  There exist a
paper which describes two variants which are work efficient [2] which
has `O(log n)` span, this project is about implementing some of these.
A things to keep in mind, the `k` constant should probably be adjusted
to have some linear factor for a GPU.  In this project you will have
an opportunity to use a flattening transformation and hopefully end up
with something faster than the implementation given.  If there is time
maybe consider if doing a blocked implementation that utilizes the
shared memory inside a GPU block will give better performance.  And
lastly if there is even more time there exists a work efficient
implementation [3] with O(log log n) span that you could implement.

[1] Ilan Bar-on and Uzi Vishkin. 1985. Optimal parallel generation of
a computation tree form. ACM Trans. Program. Lang. Syst. 7, 2 (April
1985), 348–357. https://doi.org/10.1145/3318.3478

[2] Nodari Sitchinava and Rolf Svenning. 2024. The All Nearest Smaller
Values Problem Revisited in Practice, Parallel and External Memory. In
Proceedings of the 36th ACM Symposium on Parallelism in Algorithms and
Architectures (SPAA '24). Association for Computing Machinery, New
York, NY, USA, 259–268. https://doi.org/10.1145/3626183.3659979

[3] O. Berkman, B. Schieber, U. Vishkin, Optimal Doubly Logarithmic
Parallel Algorithms Based On Finding All Nearest Smaller Values,
Journal of Algorithms, Volume 14, Issue 3, 1993, Pages 344-370, ISSN
0196-6774, https://doi.org/10.1006/jagm.1993.1018.

P.S. I realized later that being able to solve for the next smaller or
equal element can be used for solving subtree_sizes work efficiently
and also do parallel bracket matching. Found also another version with
a better complexity [here](https://doi.org/10.1006/jagm.1997.0905).

## List Ranking

In the course you have been taught about Wyllies list ranking
algorithm [1] which allows for finding the distance from a given node
to its head node.  As mentioned beforehand Wyllies list ranking
algorithm does O(n log n) work and has O(log n) span so it is not work
efficient.  This project is about implementing an work efficient
version of list ranking, the first of such was described by Cole and
Vishkin [2].  The Cole and Vishkin algorith is very complicated and
later Anderson and Miller described a much less complicated algorithm
[3].  There are also other examples of list ranking algorithms which
uses random mate [4].  It would be interesting to benchmark some of
these versions against each other and see how they can be use on tree
or forest structures.

[1] James C. Wyllie. 1979. The Complexity of Parallel Computations.
Technical Report TR79-387. Cornell University, Ithaca, NY, USA.
https://hdl.handle.net/1813/7502

[2] Cole, R., and Vishkin, U. 1986. Deterministic coin tossing with
applications to optimal parallel list ranking. Information and Control
70, 1, 32–53. https://doi.org/10.1016/S0019-9958(86)80023-7

[3] Anderson, R.J., Miller, G.L. Deterministic parallel list
ranking. Algorithmica 6, 859–868
(1991). https://doi.org/10.1007/BF01759076

[4] Margaret Reid-Miller, Gary L. Miller, and Francesmary
Modugno. List Ranking and Parallel Tree Contraction. In John Reif,
editor, Synthesis of Parallel Algorithms, pp. 115–194, Morgan
Kaufmann, 1993. https://www.cs.cmu.edu/~glmiller/Publications/Papers/ReMiMo93.pdf

## Vector Data Structures

A V-Tree is a data structure with a vector representation which
describes a tree like the parent vector does.  They are found in
Blelloch PhD Thesis [1, pp. 84-91] and they represent an Euler tour of
the tree.  This is a representation also described by Tarjan and
Vishkin but a V-Tree uses an array instead of linked list.  Many
operations on these trees can be found in the following [Futhark
library](https://github.com/diku-dk/vtree), but there are still some
things missing.  Blelloch describes how to turn a parent vector or a
V-Graph [1, pp. 79-84] into a V-Tree and adding these conversion
functions to the library would be part of the project.  Here a V-Graph
is a vector representation of a graph so making such a library could
also be part of the project.  There are also operations such as
splitting and merging these trees that could be part of the project.
The V-Graphs could also be used to implement a minimum spanning tree
algorithm [1, pp 110-113].

[1] Guy E. Blelloch. 1990. Vector models for data-parallel
computing. MIT Press, Cambridge, MA, USA.

[2] Robert E. Tarjan and Uzi Vishkin. 1985. An Efficient Parallel
Biconnectivity Algorithm. SIAM Journal on Computing 14, 4 (1985),
862–874. https://doi.org/10.1137/0214061

## Evaluating Expressions

There is an old article about evaluating expressions in parallel, part
of the implementation can be found
[here](https://github.com/diku-dk/containers/blob/main/lib/github.com/diku-dk/containers/reduction_tree.fut).
It would be interesting to use this together with the
[Alpacc](https://github.com/diku-dk/alpacc) parser generator to have
data-parallel parsing and evaluation of expressions.  There are other
ways this can be done like using Parallel Tree Contraction [2] and it
is possible to use this for other problems [3].

[1] Ilan Bar-on and Uzi Vishkin. 1985. Optimal parallel generation of
a computation tree form. ACM Trans. Program. Lang. Syst. 7, 2 (April
1985), 348–357. https://doi.org/10.1145/3318.3478

[2] Margaret Reid-Miller, Gary L. Miller, and Francesmary
Modugno. List Ranking and Parallel Tree Contraction. In John Reif,
editor, Synthesis of Parallel Algorithms, pp. 115–194, Morgan
Kaufmann, 1993. https://www.cs.cmu.edu/~glmiller/Publications/Papers/ReMiMo93.pdf

[3] "Tree Contraction." Wikipedia, Wikimedia Foundation, 10 Dec. 2025,
en.wikipedia.org/wiki/Tree_contraction.

