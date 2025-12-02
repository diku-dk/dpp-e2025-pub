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
* [delaunayTriangulation](https://cmuparlay.github.io/pbbsbench/benchmarks/delaunayTriangulation.html)
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
This problem can be improved by using sorting or a prefix tree of minima [1] to get `O(n log n)` work and `O(n)` span (see code provided below).
There exist a paper which describes two variants which are work efficient [2] which has `O(log n)` span, this project is about implementing some of these.
Things to keep is mind the `k` constant should probably be adjusted to have some linear factor for a GPU.
In this project you will have an opportunity to use a flattening transformation and hopefully end up with something faster than the implementation given.
If there is time maybe consider if doing a blocked implementation that utilizes the shared memory inside a GPU block will give better performance.
And lastly if there is even more time there exists a work efficient implementation [3] with O(log log n) span that you could implement.  

[1] Ilan Bar-on and Uzi Vishkin. 1985. Optimal parallel generation of a computation tree form. ACM Trans. Program. Lang. Syst. 7, 2 (April 1985), 348–357. https://doi.org/10.1145/3318.3478

[2] Nodari Sitchinava and Rolf Svenning. 2024. The All Nearest Smaller Values Problem Revisited in Practice, Parallel and External Memory. In Proceedings of the 36th ACM Symposium on Parallelism in Algorithms and Architectures (SPAA '24). Association for Computing Machinery, New York, NY, USA, 259–268. https://doi.org/10.1145/3626183.3659979

[3] O. Berkman, B. Schieber, U. Vishkin, Optimal Doubly Logarithmic Parallel Algorithms Based On Finding All Nearest Smaller Values, Journal of Algorithms, Volume 14, Issue 3, 1993, Pages 344-370, ISSN 0196-6774, https://doi.org/10.1006/jagm.1993.1018.

```fut
def backwards_linear_search [n] 't
                            (op: t -> t -> bool)
                            (arr: [n]t)
                            (i: i64) : i64 =
  loop j = i - 1
  while j != -1 && not (arr[j] `op` arr[i]) do
    j - 1

def size (h: i64) : i64 =
  (1 << h) - 1

def mk_tree [n] 't (op: t -> t -> t) (ne: t) (arr: [n]t) =
  let temp = i64.num_bits - i64.clz n
  let h = i64.i32 <| if i64.popc n == 1 then temp else temp + 1
  let tree_size = size h
  let offset = size (h - 1)
  let offsets = iota n |> map (+ offset)
  let tree = scatter (replicate tree_size ne) offsets arr
  let arr = copy tree[offset:]
  let (tree, _, _) =
    loop (tree, arr, level) = (tree, arr, h - 2)
    while level >= 0 do
      let new_size = length arr / 2
      let new_arr =
        tabulate new_size (\i -> arr[2 * i] `op` arr[2 * i + 1])
      let offset = size level
      let offsets = iota new_size |> map (+ offset)
      let new_tree = scatter tree offsets new_arr
      in (new_tree, new_arr, level - 1)
  in tree

def find_previous [n] 't
                  (op: t -> t -> bool)
                  (tree: [n]t)
                  (idx: i64) : i64 =
  let sibling i = i - i64.bool (i % 2 == 0) + i64.bool (i % 2 == 1)
  let parent i = (i - 1) / 2
  let is_left i = i % 2 == 1
  let h = i64.i32 <| i64.num_bits - i64.clz n
  let offset = size (h - 1)
  let start = offset + idx
  let v = tree[start]
  let ascent i = i != 0 && (is_left i || !(tree[sibling i] `op` v))
  let descent i = 2 * i + 1 + i64.bool (tree[2 * i + 2] `op` v)
  let index = iterate_while ascent parent start
  in if index != 0
     then iterate_while (< offset) descent (sibling index) - offset
     else -1
```
P.S. I realized later that being able to solve for the next smaller or
equal element can be used for solving subtree_sizes work efficiently
and also do parallel bracket matching.
