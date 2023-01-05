# neofetch-linux

a linux distribution that boots, immediately runs neofetch, and then drops you to a prompt that can do nothing but run neofetch again.

<img src="screenshot.png" width="500" alt="a screenshot of neofetch linux, which shows a partially obscured neofetch output followed by a shell prompt. running ls in the shell prompt results in an invalid command message, with the list of valid commands helpfully listed (neofetch). running neofetch displays neofetch output again.">

## build

```
$ ./build.sh fetch      # fetch required source code (linux kernel, musl cross-compiler, busybox, bash, neofetch)
$ ./build.sh build      # build neofetch-linux.iso
```

## license

the code provided in this repository (build.sh, grub.cfg, sethostname.c, and init script) are under the MIT license; see LICENSE.md. the components fetched and built by the build script are provided by their respective authors under their respective terms.
