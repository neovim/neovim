# YouCompleteMe

## Installation

### Step 1

Install [YouCompleteMe](https://github.com/Valloric/YouCompleteMe).

### Step 2

```bash
cp ycm_extra_conf.py ../../src/nvim/.ycm_extra_conf.py
echo src/nvim/.ycm_extra_conf.py >> ../../.git/info/exclude
make -C ../.. cmake
```
