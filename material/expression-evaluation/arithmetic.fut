-- Terminal Encoding:
-- T "num": 0
-- TLit "(": 1
-- TLit ")": 2
-- TLit "*": 3
-- TLit "+": 4
-- TLit "-": 5
-- TLit "/": 6
-- T "ignore": 7

-- Start of lexer.fut
--
-- The generic parallel lexer, expressed as a parameterised
-- module.

import "lib/github.com/diku-dk/containers/opt"

module type lexer_context = {
  module endomorphism_module: integral
  module terminal_module: integral
  val identity_endomorphism : endomorphism_module.t
  val endomorphism_size : i64
  val endo_mask : endomorphism_module.t
  val terminal_mask : endomorphism_module.t
  val produce_mask : endomorphism_module.t
  val endo_offset : endomorphism_module.t
  val terminal_offset : endomorphism_module.t
  val produce_offset : endomorphism_module.t
  val ignore_terminal : opt terminal_module.t
  val transitions_to_endomorphisms : [256]endomorphism_module.t
  val compositions : [endomorphism_size * endomorphism_size]endomorphism_module.t
  val dead_terminal : terminal_module.t
  val accept_array : [endomorphism_size]bool
}

module type lexer = {
  type terminal
  val lex [n] : i32 -> [n]u8 -> opt ([](terminal, (i64, i64)))
}

module mk_lexer (L: lexer_context) : lexer with terminal = L.terminal_module.t = {
  type endomorphism = L.endomorphism_module.t
  type terminal = L.terminal_module.t

  def get_value (mask: endomorphism)
                (offset: endomorphism)
                (a: endomorphism) : endomorphism =
    let a' = mask L.endomorphism_module.& a
    in a' L.endomorphism_module.>> offset

  def is_produce (a: endomorphism) : bool =
    get_value L.produce_mask L.produce_offset a
    |> L.endomorphism_module.to_i64
    |> bool.i64

  def to_terminal (a: endomorphism) : terminal =
    get_value L.terminal_mask L.terminal_offset a
    |> L.endomorphism_module.to_i64
    |> L.terminal_module.i64

  def to_index (a: endomorphism) : i64 =
    get_value L.endo_mask L.endo_offset a
    |> L.endomorphism_module.to_i64

  def is_accept (a: endomorphism) : bool =
    L.accept_array[to_index a]

  def compose (a: endomorphism) (b: endomorphism) : endomorphism =
    #[unsafe]
    let a' = to_index a
    let b' = to_index b
    in copy L.compositions[b' * L.endomorphism_size + a']

  def trans_to_endo (prev_endo: endomorphism) (c: u8) (i: i64) : endomorphism =
    let e = copy L.transitions_to_endomorphisms[u8.to_i64 c]
    in if i == 0
       then prev_endo `compose` e
       else e

  def traverse [n] (prev_endo: endomorphism) (str: [n]u8) : *[n]endomorphism =
    map2 (trans_to_endo prev_endo) str (iota n)
    |> scan compose L.identity_endomorphism

  def take_right a b =
    if b == i64.highest then a else b

  def is_ignore t =
    match L.ignore_terminal
    case #some t' -> t L.terminal_module.== t'
    case #none -> false

  def lex_step [n]
               (offset: i64)
               (prev_endo: endomorphism)
               (prev_start: i64)
               (str: [n]u8) : ([](terminal, (i64, i64)), endomorphism, i64) =
    let endos = traverse prev_endo str
    let flags =
      tabulate n (\i ->
                    i != n - 1
                    && is_produce endos[i + 1]
                    && (not <-< is_ignore <-< to_terminal) endos[i])
    let is =
      map i64.bool flags
      |> scan (+) 0
    let offsets = map2 (\f o -> if f then o - 1 else -1) flags is
    let starts =
      tabulate n (\i ->
                    if is_produce endos[i] && (not <-< is_ignore <-< to_terminal) endos[i]
                    then i
                    else if i == 0 then take_right (prev_start - offset) i64.highest else i64.highest)
      |> scan take_right i64.highest
    let ends = iota n
    let vs = zip (map to_terminal endos) (zip starts ends)
    let dest = replicate n (L.terminal_module.u8 0, (0, 0))
    let result =
      scatter dest offsets vs
      |> map (\(t, (s, e)) -> (t, (s + offset, 1 + e + offset)))
    let size = is[n - 1]
    let last_endo = endos[n - 1]
    let last_start = starts[n - 1]
    in ( result[0:size]
       , last_endo
       , if last_start != i64.highest then offset + last_start else prev_start
       )

  def lex [n]
          (chunk_size: i32)
          (str: [n]u8) : opt ([](terminal, (i64, i64))) =
    let chunk_size' = i64.i32 chunk_size
    let (res, final_endo, final_start) =
      loop (res'', init_endo, init_start) = ([], L.identity_endomorphism, 0)
      for offset in 0..chunk_size'..<n do
        let m = i64.min (offset + chunk_size' + 1) n
        let (res', last_endo, last_start) = lex_step offset init_endo init_start str[offset:m]
        in (res'' ++ res', last_endo, last_start)
    let last_terminal = to_terminal final_endo
    let last =
      if is_ignore last_terminal
      then []
      else [(to_terminal final_endo, (final_start, n))]
    let result = some (res ++ last)
    in if is_accept final_endo
       then result
       else #none
}

-- End of lexer.fut
module lexer = mk_lexer {
  module terminal_module = u8
  module endomorphism_module = u16

  type endomorphism = endomorphism_module.t
  type terminal = terminal_module.t

  def identity_endomorphism : endomorphism = 256
  def dead_terminal : terminal = 8
  def ignore_terminal : opt terminal = #some 7
  def endo_mask : endomorphism = 31
  def endo_offset : endomorphism = 0
  def terminal_mask : endomorphism = 480
  def terminal_offset : endomorphism = 5
  def produce_mask : endomorphism = 512
  def produce_offset : endomorphism = 9

  def endomorphism_size : i64 = 19

  def accept_array : [endomorphism_size]bool =
    sized endomorphism_size [false, false, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true, true]

  def transitions_to_endomorphisms : [256]endomorphism =
    sized 256 [257, 257, 257, 257, 257, 257, 257, 257, 257, 226, 226, 257, 257, 226, 257, 257, 257, 257, 257, 257, 257, 257, 257, 257, 257, 257, 257, 257, 257, 257, 257, 257, 226, 257, 257, 257, 257, 257, 257, 257, 35, 68, 101, 134, 257, 167, 257, 200, 9, 9, 9, 9, 9, 9, 9, 9, 9, 9, 257, 257, 257, 257, 257, 257, 257, 257, 257, 257, 257, 257, 257, 257, 257, 257, 257, 257, 257, 257, 257, 257, 257, 257, 257, 257, 257, 257, 257, 257, 257, 257, 257, 257, 257, 257, 257, 257, 257, 257, 257, 257, 257, 257, 257, 257, 257, 257, 257, 257, 257, 257, 257, 257, 257, 257, 257, 257, 257, 257, 257, 257, 257, 257, 257, 257, 257, 257, 257, 257, 257, 257, 257, 257, 257, 257, 257, 257, 257, 257, 257, 257, 257, 257, 257, 257, 257, 257, 257, 257, 257, 257, 257, 257, 257, 257, 257, 257, 257, 257, 257, 257, 257, 257, 257, 257, 257, 257, 257, 257, 257, 257, 257, 257, 257, 257, 257, 257, 257, 257, 257, 257, 257, 257, 257, 257, 257, 257, 257, 257, 257, 257, 257, 257, 257, 257, 257, 257, 257, 257, 257, 257, 257, 257, 257, 257, 257, 257, 257, 257, 257, 257, 257, 257, 257, 257, 257, 257, 257, 257, 257, 257, 257, 257, 257, 257, 257, 257, 257, 257, 257, 257, 257, 257, 257, 257, 257, 257, 257, 257, 257, 257, 257, 257, 257, 257, 257, 257, 257, 257, 257, 257, 257, 257, 257, 257, 257, 257]

  def compositions : [endomorphism_size * endomorphism_size]endomorphism =
    [256u16, 257u16, 226u16, 35u16, 68u16, 101u16, 134u16, 167u16, 200u16, 9u16, 746u16, 555u16, 588u16, 621u16, 654u16, 687u16, 720u16, 529u16, 18u16, 257u16, 257u16, 257u16, 257u16, 257u16, 257u16, 257u16, 257u16, 257u16, 257u16, 257u16, 257u16, 257u16, 257u16, 257u16, 257u16, 257u16, 257u16, 257u16, 226u16, 257u16, 746u16, 746u16, 746u16, 746u16, 746u16, 746u16, 746u16, 746u16, 746u16, 746u16, 746u16, 746u16, 746u16, 746u16, 746u16, 746u16, 746u16, 35u16, 257u16, 555u16, 555u16, 555u16, 555u16, 555u16, 555u16, 555u16, 555u16, 555u16, 555u16, 555u16, 555u16, 555u16, 555u16, 555u16, 555u16, 555u16, 68u16, 257u16, 588u16, 588u16, 588u16, 588u16, 588u16, 588u16, 588u16, 588u16, 588u16, 588u16, 588u16, 588u16, 588u16, 588u16, 588u16, 588u16, 588u16, 101u16, 257u16, 621u16, 621u16, 621u16, 621u16, 621u16, 621u16, 621u16, 621u16, 621u16, 621u16, 621u16, 621u16, 621u16, 621u16, 621u16, 621u16, 621u16, 134u16, 257u16, 654u16, 654u16, 654u16, 654u16, 654u16, 654u16, 654u16, 654u16, 654u16, 654u16, 654u16, 654u16, 654u16, 654u16, 654u16, 654u16, 654u16, 167u16, 257u16, 687u16, 687u16, 687u16, 687u16, 687u16, 687u16, 687u16, 687u16, 687u16, 687u16, 687u16, 687u16, 687u16, 687u16, 687u16, 687u16, 687u16, 200u16, 257u16, 720u16, 720u16, 720u16, 720u16, 720u16, 720u16, 720u16, 720u16, 720u16, 720u16, 720u16, 720u16, 720u16, 720u16, 720u16, 720u16, 720u16, 9u16, 257u16, 529u16, 529u16, 529u16, 529u16, 529u16, 18u16, 529u16, 18u16, 529u16, 529u16, 529u16, 529u16, 529u16, 18u16, 529u16, 18u16, 18u16, 746u16, 257u16, 746u16, 746u16, 746u16, 746u16, 746u16, 746u16, 746u16, 746u16, 746u16, 746u16, 746u16, 746u16, 746u16, 746u16, 746u16, 746u16, 746u16, 555u16, 257u16, 555u16, 555u16, 555u16, 555u16, 555u16, 555u16, 555u16, 555u16, 555u16, 555u16, 555u16, 555u16, 555u16, 555u16, 555u16, 555u16, 555u16, 588u16, 257u16, 588u16, 588u16, 588u16, 588u16, 588u16, 588u16, 588u16, 588u16, 588u16, 588u16, 588u16, 588u16, 588u16, 588u16, 588u16, 588u16, 588u16, 621u16, 257u16, 621u16, 621u16, 621u16, 621u16, 621u16, 621u16, 621u16, 621u16, 621u16, 621u16, 621u16, 621u16, 621u16, 621u16, 621u16, 621u16, 621u16, 654u16, 257u16, 654u16, 654u16, 654u16, 654u16, 654u16, 654u16, 654u16, 654u16, 654u16, 654u16, 654u16, 654u16, 654u16, 654u16, 654u16, 654u16, 654u16, 687u16, 257u16, 687u16, 687u16, 687u16, 687u16, 687u16, 687u16, 687u16, 687u16, 687u16, 687u16, 687u16, 687u16, 687u16, 687u16, 687u16, 687u16, 687u16, 720u16, 257u16, 720u16, 720u16, 720u16, 720u16, 720u16, 720u16, 720u16, 720u16, 720u16, 720u16, 720u16, 720u16, 720u16, 720u16, 720u16, 720u16, 720u16, 529u16, 257u16, 529u16, 529u16, 529u16, 529u16, 529u16, 529u16, 529u16, 529u16, 529u16, 529u16, 529u16, 529u16, 529u16, 529u16, 529u16, 529u16, 529u16, 18u16, 257u16, 18u16, 18u16, 18u16, 18u16, 18u16, 18u16, 18u16, 18u16, 18u16, 18u16, 18u16, 18u16, 18u16, 18u16, 18u16, 18u16, 18u16] :> [endomorphism_size * endomorphism_size]endomorphism
}

-- Start of parser.fut
--
-- The generic LLP parsing machine, expressed as a parameterised
-- module.

import "lib/github.com/diku-dk/sorts/radix_sort"
import "lib/github.com/diku-dk/sorts/merge_sort"
import "lib/github.com/diku-dk/containers/opt"
import "lib/github.com/diku-dk/segmented/segmented"

module type parser_context = {
  module terminal_module: integral
  module production_module: integral
  module bracket_module: integral
  val empty_terminal : terminal_module.t
  val q : i64
  val k : i64
  val number_of_productions : i64
  val production_to_terminal : [number_of_productions](opt terminal_module.t)
  val production_to_arity : [number_of_productions]i64
  val start_terminal : terminal_module.t
  val end_terminal : terminal_module.t
  val hash_table_size : i64
  val max_iters : i64
  val productions_size : i64
  val stacks_size : i64
  val hash_table : [hash_table_size](bool, [q + k]terminal_module.t, ((i64, i64), (i64, i64)))
  val stacks : [stacks_size]bracket_module.t
  val productions : [productions_size]production_module.t
}

module mk_parser (P: parser_context) = {
  module terminal_module = P.terminal_module
  module production_module = P.production_module
  module bracket_module = P.bracket_module

  type terminal = terminal_module.t
  type production = production_module.t
  type bracket = bracket_module.t

  def empty_terminal = P.empty_terminal

  def is_left (s: bracket) : bool =
    bracket_module.get_bit (bracket_module.num_bits - 1) s
    |> bool.i32

  def hash [n] (arr: [n]terminal) : u64 =
    foldl (\h a ->
             let h' = h ^ u64.i64 (terminal_module.to_i64 a)
             in h' * 1099511628211)
          14695981039346656037
          arr

  def get_key [n] (arr: [n]terminal) (i: i64) : [P.q + P.k]terminal =
    #[inline]
    #[sequential]
    tabulate (P.q + P.k)
             (\j ->
                if i + j < P.q || i + j >= n + P.q then empty_terminal else arr[i + j - P.q])

  def array_equal [n] 'a (eq: a -> a -> bool) (as: [n]a) (bs: [n]a) : bool =
    #[inline]
    #[sequential]
    map2 eq as bs
    |> and

  def lookup (k: [P.q + P.k]terminal) : ((i64, i64), (i64, i64)) =
    let h = (hash k) %% u64.i64 P.hash_table_size
    let (_, _, _, v) =
      loop (is_found, i, h, v) = (false, 0, h, ((-1, -1), (-1, -1)))
      while is_found || i < P.max_iters do
        let (t, k', v') = P.hash_table[i64.u64 h]
        let is_valid = t && (array_equal (terminal_module.==) k' k)
        in ( is_valid
           , i + 1
           , (h + 1) %% u64.i64 P.hash_table_size
           , if is_valid then v' else v
           )
    in v

  def keys [n] (arr: [n]terminal) : [n]((i64, i64), (i64, i64)) =
    tabulate n
             (\i ->
                let key = get_key arr i
                in lookup key)

  def valid_keys [n] : [n]((i64, i64), (i64, i64)) -> bool =
    all (\((a, b), (c, d)) -> a != -1 && b != -1 && c != -1 && d != -1)

  def depths [n] (input: [n]bracket) : opt ([n]i64) =
    let left_brackets =
      input
      |> map (is_left)
    let bracket_scan =
      left_brackets
      |> map (\b -> if b then 1 else -1)
      |> scan (+) 0
    let result =
      bracket_scan
      |> map2 (\a b -> b - i64.bool a) left_brackets
    in if any (< 0) bracket_scan || (n != 0 && last bracket_scan != 0)
       then #none
       else #some result

  def grade [n] (xs: [n]i64) : [n]i64 =
    zip xs (indices xs)
    |> blocked_radix_sort_int_by_key 256 (.0) i64.num_bits i64.get_bit
    |> map (.1)

  def even_indices 'a [n] (_: [n]a) : [n / 2]i64 =
    iota (n / 2) |> map (2 *)

  def unpack_bracket (b: bracket) : bracket =
    bracket_module.set_bit (bracket_module.num_bits - 1) b 0

  def eq_no_bracket (a: bracket) (b: bracket) : bool =
    unpack_bracket a bracket_module.== unpack_bracket b

  def brackets_matches [n] (brackets: [n]bracket) : bool =
    match depths brackets
    case #some depths' ->
      let grade' = grade depths'
      in even_indices grade'
         |> map (\i -> eq_no_bracket brackets[grade'[i]] brackets[grade'[i + 1]])
         |> and
    case #none -> false

  def gather [n] [m] 'a (arr: [n]a) (is: [m]i64) : [m]a =
    map (\i -> arr[i]) is

  def gather_scatter 'a [n] [m] [k]
                     (dest: *[n]a)
                     (mapping: [m](i64, i64))
                     (vs: [k]a) : *[n]a =
    let (is', is) = unzip mapping
    let vs = gather vs is'
    in scatter dest is vs

  def exscan [n] 'a (op: a -> a -> a) (ne: a) (as: [n]a) =
    if length as == 0
    then (ne, as)
    else let res = scan op ne as |> rotate (-1)
         let l = copy res[0]
         let res[0] = ne
         in (l, res)

  def create_flags [n] 't
                   (default: t)
                   (flags: [n]t)
                   (shape: [n]i64) : []t =
    let (m, offsets) = exscan (+) 0 shape
    let idxs =
      map2 (\i j -> if i == 0 then -1 else j)
           shape
           offsets
    in scatter (replicate m default) idxs flags

  def segmented_copy [n] [m] 'a
                     (arr: [m]a)
                     (spans: [n](i64, i64)) : []a =
    let (starts, ends) = unzip spans
    let shape = map2 (-) ends starts
    let (seg_idxs, idxs) = repl_segm_iota shape
    let dest = replicate (length idxs) arr[0]
    let offsets =
      gather starts seg_idxs
      |> map2 (+) idxs
      |> flip zip (indices idxs)
    in gather_scatter dest offsets arr

  def construct_stacks =
    segmented_copy P.stacks

  def construct_productions =
    segmented_copy P.productions

  def to_keys arr =
    let arr' = [P.start_terminal] ++ arr ++ [P.end_terminal]
    let idxs = keys arr'
    in if valid_keys idxs
       then some idxs
       else #none

  def to_productions [n] (ks: [n]((i64, i64), (i64, i64))) : opt ([]production) =
    let (stack_spans, productions_spans) = unzip ks
    let stacks = construct_stacks stack_spans
    let is_valid = brackets_matches stacks
    let prods =
      if is_valid
      then construct_productions productions_spans
      else []
    in if is_valid
       then #some prods
       else #none

  def pre_productions [n] (arr: [n]terminal) : opt ([]production) =
    let ks' = to_keys arr
    let ks =
      match ks'
      case #some k -> k
      case #none -> []
    let prods = to_productions ks
    in if is_some ks'
       then prods
       else #none

  def production_to_terminal (p: production) : opt terminal =
    copy P.production_to_terminal[production_module.to_i64 p]

  def production_to_arity (p: production) : i64 =
    copy P.production_to_arity[production_module.to_i64 p]

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

  def parents [n] (ps: [n]production) : [n]i64 =
    let tree =
      map production_to_arity ps
      |> map (+ -1)
      |> exscan (+) 0
      |> (.1)
      |> mk_tree i64.min i64.highest
    let parents' = map (find_previous (<=) tree) (iota n)
    in if n == 0
       then parents'
       else let parents'[0] = 0 in parents'

  def backwards_linear_search [n] 't
                              (op: t -> t -> bool)
                              (arr: [n]t)
                              (i: i64) : i64 =
    loop j = i - 1
    while j != -1 && not (arr[j] `op` arr[i]) do
      j - 1

  def test_previous_equal_or_smaller [n] (arr: [n]i32) : bool =
    let expected = map (backwards_linear_search (<=) arr) (iota n)
    let tree = mk_tree i32.min i32.highest arr
    let result = map (find_previous (<=) tree) (iota n)
    in zip expected result
       |> all (uncurry (==))

  type node 't 'p = #terminal t (i64, i64) | #production p

  def safe_zip [n] [m] 'a 'b (a: [n]a) (b: [m]b) =
    if n == m
    then zip a (sized n b)
    else assert true []

  def terminal_offsets [n] [m]
                       (spans: [m](i64, i64))
                       (ts: [n](opt terminal)) : [](i64, node terminal production) =
    map (is_some) ts
    |> zip3 (iota n) (ts)
    |> filter (\(_, _, b) -> b)
    |> safe_zip spans
    |> map (\(s, (i, t, _)) ->
              from_opt empty_terminal t
              |> (\t' -> (i, #terminal t' s)))

  def parse [n] (arr: [n](terminal, (i64, i64))) : opt ([](i64, node terminal production)) =
    let (ters, spans) = unzip arr
    let prods' = ters |> pre_productions
    let result =
      match prods'
      case #some prods ->
        let parent_vector = parents prods
        let ts = map production_to_terminal prods
        let (offsets, tprods) = terminal_offsets spans ts |> unzip
        let prods =
          map (\p -> #production p)
              prods
          :> [](node terminal production)
        in scatter prods offsets tprods
           |> zip parent_vector
      case _ -> []
    in if is_some prods' then some result else #none
}

-- End of parser.fut
module parser = mk_parser {
  module terminal_module = u8
  module production_module = u8
  module bracket_module = u8

  type terminal = terminal_module.t
  type production = production_module.t
  type bracket = bracket_module.t

  def left (s: bracket) : bracket =
    bracket_module.set_bit (bracket_module.num_bits - 1) s 1

  def right (s: bracket) : bracket =
    bracket_module.set_bit (bracket_module.num_bits - 1) s 0

  def number_of_productions : i64 = 19
  def q : i64 = 1
  def k : i64 = 1
  def empty_terminal : terminal = 8
  def start_terminal : terminal = 9
  def end_terminal : terminal = 10

  def production_to_terminal : [number_of_productions](opt terminal) =
    [#none, #none, #none, #none, #none, #none, #none, #none, #none, #none, #some 0, #some 7, #some 1, #some 2, #some 3, #some 4, #some 5, #some 6, #none] :> [number_of_productions](opt terminal)

  def production_to_arity : [number_of_productions]i64 =
    [2, 3, 3, 0, 2, 3, 3, 0, 1, 3, 0, 0, 0, 0, 0, 0, 0, 0, 1] :> [number_of_productions]i64

  def hash_table_size : i64 = 52
  def max_iters : i64 = 3
  def productions_size : i64 = 66
  def stacks_size : i64 = 78

  def hash_table : [hash_table_size](bool, [q + k]terminal, ((i64, i64), (i64, i64))) =
    [(true, [6, 1], ((65, 68), (56, 58))), (false, [0, 2], ((0, 3), (0, 3))), (false, [0, 2], ((0, 3), (0, 3))), (true, [9, 1], ((73, 78), (62, 66))), (false, [0, 2], ((0, 3), (0, 3))), (false, [0, 2], ((0, 3), (0, 3))), (false, [0, 2], ((0, 3), (0, 3))), (false, [0, 2], ((0, 3), (0, 3))), (false, [0, 2], ((0, 3), (0, 3))), (false, [0, 2], ((0, 3), (0, 3))), (false, [0, 2], ((0, 3), (0, 3))), (true, [0, 10], ((17, 20), (13, 15))), (false, [0, 2], ((0, 3), (0, 3))), (true, [3, 1], ((49, 52), (40, 42))), (true, [0, 4], ((6, 10), (5, 8))), (false, [0, 2], ((0, 3), (0, 3))), (true, [1, 0], ((20, 23), (15, 19))), (false, [0, 2], ((0, 3), (0, 3))), (false, [0, 2], ((0, 3), (0, 3))), (false, [0, 2], ((0, 3), (0, 3))), (true, [9, 0], ((70, 73), (58, 62))), (true, [4, 0], ((52, 54), (42, 45))), (false, [0, 2], ((0, 3), (0, 3))), (true, [5, 1], ((60, 64), (51, 54))), (false, [0, 2], ((0, 3), (0, 3))), (false, [0, 2], ((0, 3), (0, 3))), (false, [0, 2], ((0, 3), (0, 3))), (true, [2, 4], ((34, 38), (28, 31))), (false, [0, 2], ((0, 3), (0, 3))), (true, [2, 2], ((28, 31), (23, 26))), (true, [3, 0], ((48, 49), (38, 40))), (true, [0, 5], ((10, 14), (8, 11))), (true, [0, 2], ((0, 3), (0, 3))), (false, [0, 2], ((0, 3), (0, 3))), (false, [0, 2], ((0, 3), (0, 3))), (true, [6, 0], ((64, 65), (54, 56))), (false, [0, 2], ((0, 3), (0, 3))), (false, [0, 2], ((0, 3), (0, 3))), (true, [8, 9], ((68, 70), (58, 58))), (true, [4, 1], ((54, 58), (45, 48))), (true, [5, 0], ((58, 60), (48, 51))), (false, [0, 2], ((0, 3), (0, 3))), (false, [0, 2], ((0, 3), (0, 3))), (false, [0, 2], ((0, 3), (0, 3))), (true, [2, 5], ((38, 42), (31, 34))), (true, [2, 6], ((42, 45), (34, 36))), (true, [2, 3], ((31, 34), (26, 28))), (true, [10, 8], ((78, 78), (66, 66))), (true, [0, 6], ((14, 17), (11, 13))), (true, [2, 10], ((45, 48), (36, 38))), (true, [0, 3], ((3, 6), (3, 5))), (true, [1, 1], ((23, 28), (19, 23)))] :> [hash_table_size](bool, [q + k]terminal, ((i64, i64), (i64, i64)))

  def stacks : [stacks_size]bracket =
    [right 22, right 20, right 14, right 22, left 22, left 23, right 22, right 20, left 20, left 21, right 22, right 20, left 20, left 21, right 22, left 22, left 23, right 22, right 20, right 10, right 19, left 20, left 22, right 19, left 20, left 22, left 14, left 19, right 22, right 20, right 14, right 22, left 22, left 23, right 22, right 20, left 20, left 21, right 22, right 20, left 20, left 21, right 22, left 22, left 23, right 22, right 20, right 10, right 23, right 23, left 14, left 19, right 21, left 22, right 21, left 22, left 14, left 19, right 21, left 22, right 21, left 22, left 14, left 19, right 23, right 23, left 14, left 19, left 10, left 19, right 19, left 20, left 22, right 19, left 20, left 22, left 14, left 19] :> [stacks_size]bracket

  def productions : [productions_size]production =
    [7, 3, 13, 5, 14, 7, 1, 15, 7, 2, 16, 6, 17, 7, 3, 0, 4, 8, 10, 0, 4, 9, 12, 7, 3, 13, 5, 14, 7, 1, 15, 7, 2, 16, 6, 17, 7, 3, 8, 10, 9, 12, 4, 8, 10, 4, 9, 12, 4, 8, 10, 4, 9, 12, 8, 10, 9, 12, 0, 4, 8, 10, 0, 4, 9, 12] :> [productions_size]production
}

-- Start of test.fut
--
-- The generic parallel lexer tester, expressed as a parameterised
-- module.

import "lib/github.com/diku-dk/containers/opt"

def encode_u64 (a: u64) : [8]u8 =
  [ u8.u64 (a >> 56)
  , u8.u64 (a >> 48)
  , u8.u64 (a >> 40)
  , u8.u64 (a >> 32)
  , u8.u64 (a >> 24)
  , u8.u64 (a >> 16)
  , u8.u64 (a >> 8)
  , u8.u64 (a >> 0)
  ]

def decode_u64 (a: [8]u8) : u64 =
  (u64.u8 a[0] << 56)
  | (u64.u8 a[1] << 48)
  | (u64.u8 a[2] << 40)
  | (u64.u8 a[3] << 32)
  | (u64.u8 a[4] << 24)
  | (u64.u8 a[5] << 16)
  | (u64.u8 a[6] << 8)
  | (u64.u8 a[7] << 0)

module lexer_test
  (L: {
    type terminal
    val lex [n] : i32 -> [n]u8 -> opt ([](terminal, (i64, i64)))
  })
  (T: integral with t = L.terminal) = {
  type terminal = L.terminal

  def encode_terminal ((t, (i, j)): (terminal, (i64, i64))) : [24]u8 =
    sized 24 (encode_u64 (T.to_i64 t |> u64.i64)
              ++ encode_u64 (u64.i64 i)
              ++ encode_u64 (u64.i64 j))

  def encode_terminals [n] (ts: opt ([n](terminal, (i64, i64)))) : []u8 =
    match ts
    case #some ts' ->
      [u8.bool true]
      ++ encode_u64 (u64.i64 n)
      ++ flatten (map encode_terminal ts')
    case #none -> [u8.bool false]

  def test [n] (chunk_size: i32) (bytes: [n]u8) : []u8 =
    let num = take 8 bytes
    let num_tests = decode_u64 num
    let (a, _) =
      loop (result, inputs) = (num, drop 8 bytes)
      for _i < u64.to_i64 num_tests do
        let input_size = u64.to_i64 (decode_u64 (take 8 inputs))
        let inputs' = drop 8 inputs
        let input = take input_size inputs'
        let inputs'' = drop input_size inputs'
        let output = L.lex chunk_size input |> encode_terminals
        in (result ++ output, inputs'')
    in a
}

module parser_test
  (P: {
    type terminal
    type production
    val pre_productions [n] : [n]terminal -> opt ([]production)
  })
  (T: integral with t = P.terminal)
  (Q: integral with t = P.production) = {
  type terminal = P.terminal
  type production = P.production

  def encode_productions [n] (ts: opt ([n]production)) : []u8 =
    match ts
    case #some ts' ->
      [u8.bool true]
      ++ encode_u64 (u64.i64 n)
      ++ flatten (map (encode_u64 <-< u64.i64 <-< Q.to_i64) ts')
    case #none -> [u8.bool false]

  def test [n] (bytes: [n]u8) : []u8 =
    let num = take 8 bytes
    let num_tests = decode_u64 num
    let (a, _) =
      loop (result, inputs) = (num, drop 8 bytes)
      for _i < u64.to_i64 num_tests do
        let input_size = u64.to_i64 (decode_u64 (take 8 inputs))
        let inputs' = drop 8 inputs
        let input =
          take (input_size * 8) inputs'
          |> unflatten
          |> map (T.u64 <-< decode_u64)
        let inputs'' = drop (input_size * 8) inputs'
        let output =
          P.pre_productions input
          |> encode_productions
        in (result ++ output, inputs'')
    in a
}

module lexer_parser_test
  (P: {
    type terminal
    type production
    type node 't 'p = #terminal t (i64, i64) | #production p
    val parse [n] : [n]u8 -> opt ([](i64, node terminal production))
  })
  (T: integral with t = P.terminal)
  (Q: integral with t = P.production) = {
  type terminal = P.terminal
  type production = P.production
  type node 't 'p = P.node t p

  def encode_node (p: i64) (n: node terminal production) : []u8 =
    match n
    case #production t ->
      [0u8]
      ++ ((encode_u64 <-< u64.i64) p)
      ++ ((encode_u64 <-< u64.i64 <-< Q.to_i64) t)
      ++ encode_u64 0
      ++ encode_u64 0
    case #terminal t (i, j) ->
      [1u8]
      ++ ((encode_u64 <-< u64.i64) p)
      ++ ((encode_u64 <-< u64.i64 <-< T.to_i64) t)
      ++ ((encode_u64 <-< u64.i64) i)
      ++ ((encode_u64 <-< u64.i64) j)

  def encode_tree [n] (ns: opt ([n](i64, P.node terminal production))) : []u8 =
    match ns
    case #some ns' ->
      [u8.bool true]
      ++ encode_u64 (u64.i64 n)
      ++ flatten (map (uncurry encode_node) ns')
    case #none -> [u8.bool false]

  def test [n] (bytes: [n]u8) : []u8 =
    let num = take 8 bytes
    let num_tests = decode_u64 num
    let (a, _) =
      loop (result, inputs) = (num, drop 8 bytes)
      for _i < u64.to_i64 num_tests do
        let input_size = u64.to_i64 (decode_u64 (take 8 inputs))
        let inputs' = drop 8 inputs
        let input = take input_size inputs'
        let inputs'' = drop input_size inputs'
        let output =
          P.parse input
          |> encode_tree
        in (result ++ output, inputs'')
    in a
}

-- End of test.fut

entry parse s =
  let tokens' = lexer.lex 16777216 s
  let tokens =
    match tokens'
    case #some t -> t
    case #none -> []
  let cst = parser.parse tokens
  in if is_some tokens'
     then cst
     else #none

module tester = lexer_parser_test {
  type terminal = parser.terminal
  type production = parser.production
  type node 't 'p = parser.node t p
  def parse = parse
} u8 u8

entry test [n] (s: [n]u8) : []u8 = tester.test s
