EXAMPLE DATA
============

photos/   Smartphone photos (Samsung Galaxy S25 FE, automatic exposure,
          30 Sept 2026) of white light dispersed by a prism onto a paper screen.
            00_control_no_lamp.jpg    control taken with room light (NOT a valid
                                      dark frame - shown as a cautionary example)
            01_reference_white.jpg    reference: no sample
            02_sample1_a.jpg          sample 1 (blue)
            03_sample1_b.jpg          sample 1, repeat photo
            04_sample2.jpg            sample 2 (yellow)
            05_sample3.jpg            sample 3 (dark blue)
            06_sample4.jpg            sample 4 (violet)
            07_sample5.jpg            sample 5 (pink)
            cuvettes_1_to_5.jpg       the five cuvettes, left = 1, right = 5

uvvis/    Laboratory UV-Vis spectra of the same five solutions (1 cm cuvettes).
            sample1.csv ... sample5.csv          UTF-8 copies (wavelength nm,
                                                 absorbance, std. dev.)
            raw_instrument_files/sample*.CSV     original instrument exports (UTF-16)

          Lab lambda_max after baseline correction:
            1 blue 588 nm | 2 yellow 454 nm (480 nm band) | 3 dark blue 655 nm
            4 violet 570 nm | 5 pink 544 nm

Because the photos used automatic exposure, phone absorbance values are
semi-quantitative; peak positions and band order agree with the lab spectra.
