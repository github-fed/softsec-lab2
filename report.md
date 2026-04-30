### Note that this is not the final report, we have to submit a USENIX style pdf

# Library Version
We fuzz version 1.8.6 of libsixel. The reason for this choice is mentioned in Q1 Harness Design.

# Questions
## Q1 Harness Design
-[X] Describe entrypoints and justify why
-[X] Discuss alternative entrypoints and reason why rejected or why it would be worth fuzzing them too
-[ ] Walk through harness code, explain data flow from AFL++ input file to library API call
-[ ] For every guard in the code (error handling, dimension limits, etc.), explain
  why it is needed from a fuzzing perspective


Encoding and decoding sixel files are among the most used functionalities of libsixel, so ```sixel_decode()``` and ```sixel_encode()``` are interesting candidates for fuzzing.
The function ```sixel_decode()``` is annotated as deprecated, so ```sixel_decode_raw()``` seems like a better target.
From experience, resizing images can also be tricky. So while skimming through the header file in the include directory, ```sixel_frame_resize()``` also stood out as a candidate for fuzzing.
That function however contains a lot of error handling and argument checking, which we don't want to execute repeatedly in our fuzzing campaign.
So ```sixel_helper_scale_image()``` or ```sixel_helper_normalize_pixelformat()``` which are called deeper down the function stack are better targets with less overhead.

While the latter functions might not be as well explored with fuzzing as the decoding and encoding process, it is in our opinion more interesting to fuzz one of the main functionalities of the library.
Between ```sixel_decode_raw()``` and ```sixel_encode()```, the latter takes a lot of parameters as input and thus needs much more execution time to set up the inputs.
This again means that the harness would spend more time for setup that could be spent executing the library function. 
It turns out there is a CVE in decode_raw() in version 1.8.7, so we fuzz the version 1.8.6 in hopes of finding that CVE.

So we have decided on ```sixel_decode_raw()``` as our fuzzing target since it is an important functionality of the library and doesn't require as many inputs as encoding.
```sixel_encode()``` and ```sixel_helper_normalize_pixelformat()``` would still be interesting fuzzing targets for the above-mentioned reasons.

## Q2 Instrumentation and Sanitizers

## Q3 Seed Corpus and Dictionary

## Q4 Campaign Analysis

## Q5 Crash Triage

## Q6 Attack Surface Analysis

## Q7 Binary-Only Fuzzing with QEMU Mode 

## Q8 Instrumentation Depth and Performance 
