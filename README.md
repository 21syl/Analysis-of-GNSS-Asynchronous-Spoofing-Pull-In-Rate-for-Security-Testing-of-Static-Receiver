# Analysis of GNSS Asynchronous Spoofing Pull-In Rate for Security Testing of Static Receiver

[![License](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)

This repository contains the implementation code and analysis tools for our research on **GNSS asynchronous spoofing pull-in rate** in static receivers. The work focuses on evaluating security vulnerabilities of static GNSS receivers against asynchronous spoofing attacks.

## 📌 Contents
- [Overview](#overview)
- [Code Structure](#code-structure)
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

## Code Structure
```
├── src/                     # Main source code
│   ├── spoofing_simulation/ # Spoofing scenario generators
│   ├── signal_processing/   # GNSS signal analysis tools
│   ├── vulnerability_assessment/ # Security metrics calculation
│   └── utils/               # Helper functions
├── configs/                 # Configuration files
├── results/                 # Outputs directory (plots, reports)
├── docs/                    # Documentation
└── requirements.txt         # Python dependencies
```

## 🔍 Data Description
The analysis relies on several large datasets:

| Dataset Name | Description | Size | Format |
|--------------|-------------|------|--------|
| `raw_signals/` | Raw GNSS IF data samples | 78 GB | Binary (.bin) |
| `processed_traces/` | Pre-processed signal traces | 42 GB | MATLAB (.mat) |
| `spoofing_scenarios/` | Spoofing attack simulations | 35 GB | HDF5 (.h5) |
| `receiver_logs/` | Receiver state recordings | 28 GB | CSV |

### 🚫 Data Accessibility Note
Due to the large size of the datasets (total **~183 GB**), they cannot be hosted directly on GitHub. The datasets contain:
- High-resolution GNSS intermediate frequency (IF) recordings
- Multi-constellation signal captures (GPS, Galileo, Beidou)
- 12-hour continuous static receiver observations
- Spoofing attack scenarios with varying parameters (power levels, code offsets, etc.)

## ⬇️ Data Access
To request access to the datasets, please:
1. Contact: **Song Yili** at [songyili@nudt.edu.cn](mailto:songyili@nudt.edu.cn)
2. Include the subject line: **"GNSS Spoofing Data Request - [Your Institution]"**
3. Specify which datasets you need from the list above

We will provide download links via institutional file transfer service upon verification.

## 📦 Dependencies
- Python 3.8+
- Required packages:
```bash
pip install -r requirements.txt
```
Key dependencies:
- `numpy`, `scipy`, `matplotlib`
- `gnssutils` (v1.2.1+)
- `h5py`, `pyarrow`
- `scikit-learn` (for ML-based analysis)

## 🚀 Usage
1. Clone repository:
```bash
git clone https://github.com/yourusername/Analysis-of-GNSS-Asynchronous-Spoofing-Pull-In-Rate.git
```

2. Install dependencies:
```bash
pip install -r requirements.txt
```

3. Run analysis with sample config:
```bash
python main.py --config configs/basic_scenario.yaml
```

4. Generate vulnerability report:
```bash
python reports/generate_report.py --input results/simulation_1.h5
```

## 📊 Results
Example outputs include:
- Pull-in rate vs. spoofing power relationships
- Time-to-lock distributions under attack
- Vulnerability heatmaps for different receiver types
- ROC curves for spoofing detection methods

![Example Pull-in Rate Analysis](docs/pull_in_curve_example.png)  
*Figure: Pull-in rate dependence on spoofing signal power offset*

## 🤝 Contact & Data Access
For dataset requests or technical inquiries:
- **Primary Contact**: Song Yili  
  **Email**: [songyili@nudt.edu.cn](mailto:songyili@nudt.edu.cn)  
  **Affiliation**: National University of Defense Technology (NUDT)

Please allow 3-5 business days for data request processing. Academic collaboration inquiries are welcome.

## 📜 License
This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

---
*This research was supported by the National Natural Science Foundation of China (Grant No. XXXXXXXX)*
