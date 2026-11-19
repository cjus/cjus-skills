# A Chapter Whose Citations Hold

A build that reruns every step on every change wastes most of its time (in short, [it skips nothing](https://docs.example.org/guide/caching)), so the first fix is reuse. The handbook's answer is to reuse a step's stored result when nothing the step reads has changed.

<!-- src: handbook § Caching -->

The tool's own documentation adds what a reuse costs: [a cache hit skips the step entirely](https://docs.example.org/guide/caching), so its output arrives with no work done.

<!-- src: web 1 -->

The stored results do not stay forever. [When the cache is full, the oldest entries go first](https://docs.example.org/guide/eviction), which is why a step you have not run in weeks is the one most likely to rebuild.

<!-- src: web 3; fill (the consequence) -->

A URL in code is code, not a citation. To see the cache's state, run `curl http://localhost:8080/cache/status` and read the hit count it prints:

<!-- src: fill -->

```text
$ curl https://cache.internal.test/status
hits: 41   misses: 3
```

<!-- src: fill (an illustrative session) -->

## Sources and further reading

- The handbook, § Caching, for when a stored result is reused.
- Caching, Example build tool documentation, [https://docs.example.org/guide/caching](https://docs.example.org/guide/caching), for what a cache hit skips.
- Eviction, Example build tool documentation, [https://docs.example.org/guide/eviction](https://docs.example.org/guide/eviction), for the order entries leave a full cache.
- Remote caches: sharing stored results between machines.
