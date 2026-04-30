# sofsec-lab2
Lab 2 SoftSec

## Building Docker container
```bash
docker build -t group27-lab2 .
```

## Running
```bash
mkdir -p findings findings-qemu findings-persistent plot_output plot_output_qemu plot_output_persistent
docker run --rm -it \
  -v "$(pwd)/Makefile:/lab/Makefile" \
  -v "$(pwd)/src:/lab/src" \
  -v "$(pwd)/findings:/lab/findings" \
  -v "$(pwd)/findings-qemu:/lab/findings-qemu" \
  -v "$(pwd)/findings-persistent:/lab/findings-persistent" \
  -v "$(pwd)/plot_output:/lab/plot_output" \
  -v "$(pwd)/plot_output_qemu:/lab/plot_output_qemu" \
  -v "$(pwd)/plot_output_persistent:/lab/plot_output_persistent" \
  group27-lab2
```
