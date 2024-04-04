# UWPOCR

[![Latest Version](https://img.shields.io/badge/Latest-v1.0.0-green.svg)]()
[![MIT License](https://img.shields.io/github/license/mashape/apistatus.svg)]()
[![Made with Love](https://img.shields.io/badge/Made%20with-%E2%9D%A4-red.svg?colorB=e31b23)]()

VBA-UWPOCR is a simple library to use Universal Windows Platform Optical character recognition API.

## Features

* Get Text From Image File.
* Easy to use.

## Usage

##### Basic use:

```VB
    Dim ocr As New UWPOCR

    MsgBox ocr.ImageToText(ThisWorkbook.Path & "\Images\Image1.png")(0)

```

<!-- ##### More examples [here.](/Examples) -->

## Release History

See [CHANGELOG.md](CHANGELOG.md)

<!-- ## Acknowledgments & Credits -->

## License

Usage is provided under the [MIT](https://choosealicense.com/licenses/mit/) License.

Copyright © 2024, [Danysys.](https://www.danysys.com)