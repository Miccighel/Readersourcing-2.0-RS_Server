# Domain fidelity contract

This document defines the boundary between the Readersourcing domain and its
framework and infrastructure.

## Protected behavior

The migration must preserve:

- the `Readersourcing` context and its interchangeable strategies;
- the order in which `Rating#compute_scores` invokes RSM and TRM;
- rating normalization to the `[0, 1]` interval;
- chronological processing of a publication's ratings;
- the RSM update order for publication, current reader, and previous readers;
- propagation of a changed publication score to previous readers;
- the current TRM definitions of informativeness, accuracy loss, and bonus;
- persisted scores, steadiness values, goodness values, and bonuses within the
  numerical tolerance defined by the characterization tests;
- the JSON and route contract consumed by RS_Rate.

Framework callbacks, database adapters, asset tooling, HTTP clients, file
storage, and process execution are infrastructure and may change as long as the
protected behavior remains observable.

## Reference hierarchy

The migration uses these references without treating them as interchangeable:

1. The behavior of the RS_Server implementation.
2. The `GROUND_TRUTH_2` event sequence in `db/seeds.rb`.
3. Soprano and Mizzaro, *Crowdsourcing Peer Review: As We May Do*,
   DOI `10.1007/978-3-030-11226-4_21`.
4. de Alfaro and Faella, *TrueReview: A Platform for Post-Publication Peer
   Review*, arXiv `1608.07878`.
5. The `Readersourcing_OO` Python implementation used for the 2025 simulations.

RS_Server implements users/readers, publications, and ratings. The
separate author entity found in the papers and in `Readersourcing_OO` is a
domain extension outside this contract.

## Numerical tolerance

Database-like `BigDecimal` values are combined with the `Float` returned by
`Rating#normalize_score`. The final decimal digits can therefore depend on the
runtime's numeric conversions.

The characterization suite uses the Python/Ruby 3.4 values as its canonical
snapshot and applies a `2e-9` tolerance. A larger drift is considered a domain
change.

## TRM semantic question

The TRM implementation computes its logistic function as:

```ruby
1 / 1 + Math.exp(-1 * (value - 0.5))
```

This expression is part of the characterization snapshot. Its relationship
with the sigmoidal function described by TrueReview requires an explicit,
separate domain decision.
