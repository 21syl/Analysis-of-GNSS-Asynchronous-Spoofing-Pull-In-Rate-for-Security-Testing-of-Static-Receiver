# Analysis of GNSS Asynchronous Spoofing Pull-In Rate for Security Testing of Static Receiver

[![License](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)

This repository contains the implementation code and analysis tools for our research on **GNSS asynchronous spoofing pull-in rate** in static receivers. The work focuses on evaluating security vulnerabilities of static GNSS receivers against asynchronous spoofing attacks.

Y. Song et al., "**Analysis of GNSS Asynchronous Spoofing Pull-In Rate for Security Testing of Static Receiver**," in IEEE Transactions on Instrumentation and Measurement, doi: 10.1109/TIM.2026.3674288.

## 📌 Contents
- [Overview](#overview)
- [Structure](#actual-code-structure)
- [Data Description](#-data-description)
- [Dependencies](#-dependencies)
- [Usage](#-usage)
- [Results](#-results)
- [Contact & Data Access](#-contact--data-access)
- [License](#-license)

## Overview
This project provides tools to:
1. Simulate GNSS asynchronous spoofing attacks
2. Analyze pull-in rates under various spoofing parameters
3. Evaluate receiver vulnerabilities based on experimental data
4. Generate security assessment reports for static GNSS receivers

## Structure
```
├── code/                     # Main MATLAB source code
│   ├── calcLoopCoef.m        # Loop coefficient calculation
│   ├── fCWIgen.m             # CW interference generator
│   ├── fCnrEstV3.m           # CNR estimation
│   ├── fCodeGen.m            # Code generation
│   ├── fDataComb.m           # Data combination
│   ├── fMyAcquisition.m      # Signal acquisition
│   ├── fSigDataGen.m         # Signal data generation
│   ├── initSettings.m        # System initialization
│   ├── main.m                # Main processing script
│   ├── makeCaTable.m         # CA code table generation
│   ├── preRun.m              # Pre-run setup
│   └── server_result_all.m   # Result compilation
├── data_Array/               # GNSS dataset
│   └── .gitkeep              # Placeholder for data
├── data_jam/                 # Jamming  dataset
│   └── .gitkeep              # Placeholder for data
├── data_origin/              # Original dataset 
│   ├── spoof_init_-0.5chips.DAT          # Spoofing scenario
│   ├── spoof_init_-2.0chips.DAT          # Spoofing scenario
│   ├── spoof_init_-4.0chips_0.1v_prn8.DAT  # Low-power spoof
│   ├── spoof_init_-4.0chips_0.5v_prn8.DAT  # Medium-power spoof
│   └── spoof_init_-4.0chips_1.5v_prn8.DAT  # High-power spoof
├── LICENSE                   # MIT License
└── README.md                 # Project documentation
```

## 🔍 Data Description
The analysis relies on several large datasets:

| Dataset Directory | Content Type | Files | Format |
|-------------------|-------------|-------|--------|
| `data_origin/` | processing results | 5+ files | Binary (.Dat) |
| `data_Array/` | GNSS dataset | Placeholder | N/A |
| `data_jam/` | Jamming data | Placeholder | N/A |

### 🚫 Data Accessibility Note
Due to the large size of the datasets, they cannot be hosted directly on GitHub. The datasets contain:
- High-resolution GNSS intermediate frequency (IF) recordings
- Multi-constellation signal captures (GPS, Galileo, Beidou)
- Spoofing attack scenarios with varying parameters (power levels, code offsets, etc.)

## ⬇️ Data Access
To request access to the datasets, please:
1. Contact: **Song Yili** at [songyili@nudt.edu.cn](mailto:songyili@nudt.edu.cn)
2. Include the subject line: **"GNSS Spoofing Data Request - [Your Institution]"**
3. Specify which datasets you need from the list above

We will provide download links via institutional file transfer service upon verification.

## 📦 Dependencies
- MATLAB R2020b or later
- Required MATLAB Toolboxes:
  - Signal Processing Toolbox
  - Communications Toolbox
  - Parallel Computing Toolbox (recommended)



## 🤝 Contact & Data Access
For dataset requests or technical inquiries:
- **Primary Contact**: Song Yili  
  **Email**: [songyili@nudt.edu.cn](mailto:songyili@nudt.edu.cn)  
  **Affiliation**: National University of Defense Technology (NUDT)

Please allow 3-5 business days for data request processing. Academic collaboration inquiries are welcome.

## 📜 License
This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

---
