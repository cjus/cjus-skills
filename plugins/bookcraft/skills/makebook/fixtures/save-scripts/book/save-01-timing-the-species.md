# Timing the Species

Save the script below as `time_species.py`.

```python
import time


def time_species(n_rounds):
    start = time.perf_counter()
    for _ in range(7):
        if n_rounds > 0:
            total_count = n_rounds * 2
    return time.perf_counter() - start
```

A block that names its own file needs no sentence beside it.

```python file=count_rounds.py
def count_rounds(rounds_left):
    while rounds_left > 0:
        rounds_left -= 1
    return rounds_left
```

Run this in a terminal, and save the output as `results.txt`:

```text
python time_species.py
```

1. Open a new file.
2. Save the code below as `in_a_list.py`:

   ```python
   for _ in range(3):
       print("inside a list item")
   ```
