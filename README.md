# sofsec-lab2
Lab 2 SoftSec

LINK TO RAPORT:
https://www.overleaf.com/3364939794vqfqwmpyqcjr#1dd22a


## Building Docker container
```bash
docker build -t group27-lab2 .
```

## Running
```bash
mkdir -p findings seeds_images \
         plot_output
docker run --rm -it \
  -v "$(pwd)/Makefile:/lab/Makefile" \
  -v "$(pwd)/src:/lab/src" \
  -v "$(pwd)/seeds:/lab/seeds" \
  -v "$(pwd)/seeds_images:/lab/seeds_images" \
  -v "$(pwd)/sixel.dict:/lab/sixel.dict" \
  -v "$(pwd)/findings:/lab/findings" \
  -v "$(pwd)/plot_output:/lab/plot_output" \
  group27-lab2
```

## Inside the container
```bash
make        # build all harnesses
make fuzz-all   # run all campaigns in parallel
make plot   # generate afl-plot graphs
```
