# EMA Filter Description
A real-time Temperature Data Filtering system utilizing an Exponential Moving Average (EMA) algorithm. The project establishes a cross-platform data pipeline bridging an Arduino temperature sensor and a Basys3 FPGA through a Python script. 

**System Architecture & Data Flow:**
* **Data Acquisition:** An Arduino microcontroller interfaces with a physical temperature sensor, managing continuous data sampling and serial transmission.
* **Software Bridge:** A custom Python script captures the serial output from the Arduino, formats the stream, and establishes a real-time data link to the FPGA.
* **FPGA Ingestion:** A custom AXI UART interface on the Basys3 board ingests the data stream. System-wide component synchronization and data flow efficiency are maintained using the AXI4 handshake protocol.
* **Processing:** The core processing unit utilizes a recursive Finite State Machine (FSM) to continuously calculate the EMA. The necessary floating-point arithmetic logic (+, -, *) was implemented from scratch.
* **Synchronization & Output:** The final filtered data is routed directly to the Basys3 multiplexed hexadecimal display for real-time visualization.


## Demonstration
https://github.com/user-attachments/assets/f1596843-2a7f-473d-97f8-d5c1385b1f0a

