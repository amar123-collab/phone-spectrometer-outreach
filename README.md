# Phone spectrometer for public outreach
   [![DOI](https://zenodo.org/badge/DOI/10.5281/zenodo.23400260.svg)](https://doi.org/10.5281/zenodo.23400260)
MATLAB code that turns smartphone photos of a prism or grating rainbow into
absorption spectra of coloured solutions. Developed for a Researchers' Night
light-and-colour station, where visitors watch a sample remove colours from the
rainbow and see the spectrum appear on a laptop a few seconds later.

No toolboxes are needed (MATLAB R2020b or newer).

## Two versions

| Folder | What it is | Use it for |
| --- | --- | --- |
| `v1_as_used/` | The scripts exactly as used for the analysis in the article | Reproducing the published figures |
| `v2_user_friendly/` | Point-and-click app, script version and reusable functions | New measurements, classrooms, outreach events |

Each folder has a `HOW_TO_USE.txt` with step-by-step instructions.

### What v2 adds

- A guided app (`PhoneSpectrometer`): six numbered steps, status messages, errors shown as
  plain-language dialogs instead of crashes.
- Automatic rainbow detection in any orientation; spectra always run blue → red.
- Warnings when a photo's exposure time or ISO differs from the reference, when the
  rainbow is overexposed, or when a "dark" photo is brighter than the reference.
- Laser calibration with automatic spot detection and a check figure.
- Overlay of laboratory UV-Vis spectra (reads UTF-16 instrument files directly).
- Live mode for events: new photos in a synced folder are measured automatically.
- Saves CSV, figures and a log of every setting; settings can be saved and reloaded.

## Quick start

```matlab
cd v2_user_friendly
PhoneSpectrometer        % then follow HOW_TO_USE.txt with ../example_data/photos
```

or, without the app:

```matlab
cd v2_user_friendly
batch_example            % runs on the example photos as provided
uvvis_process('../example_data/uvvis')
```

## Method in one paragraph

Each photo is rotated upright using its orientation flag and converted to
linear intensity by undoing the sRGB gamma. The rainbow is located on the
reference photo, and every photo is aligned on the blue end of its rainbow.
Intensity is averaged across a strip through the middle of the rainbow,
giving I(x). Absorbance is A(x) = −log10[(I_sample − I_dark)/(I_ref − I_dark)],
ignoring the dim ends where the reference is below 30 % of its maximum.
Positions are converted to wavelength with laser lines of known wavelength
(linear fit for a grating, quadratic for a prism).

## Repository layout

```
v1_as_used/          scripts used for the article (unchanged)
v2_user_friendly/    app, script, UV-Vis tool, core functions
example_data/        test photos and matching lab UV-Vis spectra
LICENSE              MIT
CITATION.cff         how to cite
```

## Citation

If you use this code, please cite the article and this repository
(see `CITATION.cff`).

## License

MIT; see `LICENSE`.
