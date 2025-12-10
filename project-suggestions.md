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

# All Previous Smaller Element Problem
To solve the previous smaller element problem one must find the index of the first element with a smaller index which satisfies it is smaller than the current element.
When apply this to all elements we call this the all previous smaller element problem.
This problem can be used for finding the parent vector given given the depth vector of a preorder traversal of a tree as seen in previous assignments.
We have seen this can be solved be in `O(n^2)` work and `O(n)` span using backwards linear search.
This problem can be improved by using sorting or a tree of minima [1] to get `O(n log n)` work and `O(n)` span (found [here](https://github.com/diku-dk/containers/blob/main/lib/github.com/diku-dk/containers/reduction_tree.fut) this is a version with the incorrect complexity [1]).
There exist a paper which describes two variants which are work efficient [2] which has `O(log n)` span, this project is about implementing some of these.
Things to keep is mind the `k` constant should probably be adjusted to have some linear factor for a GPU.
In this project you will have an opportunity to use a flattening transformation and hopefully end up with something faster than the implementation given.
If there is time maybe consider if doing a blocked implementation that utilizes the shared memory inside a GPU block will give better performance.
And lastly if there is even more time there exists a work efficient implementation [3] with O(log log n) span that you could implement.  

[1] Ilan Bar-on and Uzi Vishkin. 1985. Optimal parallel generation of a computation tree form. ACM Trans. Program. Lang. Syst. 7, 2 (April 1985), 348–357. https://doi.org/10.1145/3318.3478

[2] Nodari Sitchinava and Rolf Svenning. 2024. The All Nearest Smaller Values Problem Revisited in Practice, Parallel and External Memory. In Proceedings of the 36th ACM Symposium on Parallelism in Algorithms and Architectures (SPAA '24). Association for Computing Machinery, New York, NY, USA, 259–268. https://doi.org/10.1145/3626183.3659979

[3] O. Berkman, B. Schieber, U. Vishkin, Optimal Doubly Logarithmic Parallel Algorithms Based On Finding All Nearest Smaller Values, Journal of Algorithms, Volume 14, Issue 3, 1993, Pages 344-370, ISSN 0196-6774, https://doi.org/10.1006/jagm.1993.1018.

P.S. I realized later that being able to solve for the next smaller or
equal element can be used for solving subtree_sizes work efficiently
and also do parallel bracket matching. Found also another version with
a better complexity [here](https://doi.org/10.1006/jagm.1997.0905).

# List Ranking
In the course you have been taught about Wyllies list ranking algorithm [1] which allows for finding the distance from a given node to its head node.
As mentioned beforehand Wyllies list ranking algorithm does O(n log n) work and has O(log n) span so it is not work efficient.
This project is about implementing an work efficient version of list ranking, the first of such was described by Cole and Vishkin [2].
The Cole and Vishkin algorith ms very complicated and later Anderson and Miller described a much less complicated algorithm [3].
There are also other examples of list ranking algorithms which uses random mate [4].
It would be interesting to benchmark some of these versions against each other and see how they can be use on tree or forest structures.

[1] James C. Wyllie. 1979. The Complexity of Parallel Computations.  Technical Report TR79-387. Cornell University, Ithaca, NY, USA.  https://hdl.handle.net/1813/7502

[2] Cole, R., and Vishkin, U. 1986. Deterministic coin tossing with applications to optimal parallel list ranking. Information and Control 70, 1, 32–53. https://doi.org/10.1016/S0019-9958(86)80023-7

[3] Anderson, R.J., Miller, G.L. Deterministic parallel list ranking. Algorithmica 6, 859–868 (1991). https://doi.org/10.1007/BF01759076

[4] Margaret Reid-Miller, Gary L. Miller, and Francesmary Modugno. List Ranking and Parallel Tree Contraction. In John Reif, editor, Synthesis of Parallel Algorithms, pp. 115–194, Morgan Kaufmann, 1993. https://www.cs.cmu.edu/~glmiller/Publications/Papers/ReMiMo93.pdf

# Vector Data Structures
A V-Tree is a data structure with a vector representation which describes a tree like the parent vector does.
They are found in Blelloch PhD Thesis [1, pp. 84-91] and they represent an Euler tour of the tree.
This is a representation also described by Tarjan and Vishkin but a V-Tree uses an array instead of linked list.
Many operations on these trees can be found in the following [Futhark library](https://github.com/diku-dk/vtree), but there are still some things missing.
Blelloch describes how to turn a parent vector or a V-Graph [1, pp. 79-84] into a V-Tree and adding these conversion functions to the library would be part of the project.
Here a V-Graph is a vector representation of a graph so making such a library could also be part of the project.
There are also operations such as splitting and merging these tree that could be be part of the project.
The V-Trees could also be used to implement a minimum spanning tree algorithm [1, pp 110-113].

[1] Guy E. Blelloch. 1990. Vector models for data-parallel computing. MIT Press, Cambridge, MA, USA.

[2] Robert E. Tarjan and Uzi Vishkin. 1985. An Efficient Parallel Biconnectivity Algorithm. SIAM Journal on Computing 14, 4 (1985), 862–874. https://doi.org/10.1137/0214061

# Evaluating Expressions
There is an old article about evaluating expressions in parallel, part of the implementation can be found [here](https://github.com/diku-dk/containers/blob/main/lib/github.com/diku-dk/containers/reduction_tree.fut).
It would interesting to use this together with the [Alpacc](https://github.com/diku-dk/alpacc) parser generator to have data-parallel paring and evaluation of expressions.
There are other ways this can be done like using Parallel Tree Contraction [2] and it is possible to use this for other problems [3].

[1] Ilan Bar-on and Uzi Vishkin. 1985. Optimal parallel generation of a computation tree form. ACM Trans. Program. Lang. Syst. 7, 2 (April 1985), 348–357. https://doi.org/10.1145/3318.3478

[2] Margaret Reid-Miller, Gary L. Miller, and Francesmary Modugno. List Ranking and Parallel Tree Contraction. In John Reif, editor, Synthesis of Parallel Algorithms, pp. 115–194, Morgan Kaufmann, 1993. https://www.cs.cmu.edu/~glmiller/Publications/Papers/ReMiMo93.pdf

[3] "Tree Contraction." Wikipedia, Wikimedia Foundation, 10 Dec. 2025, en.wikipedia.org/wiki/Tree_contraction.

