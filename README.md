# SmartFarm: AI-Powered Smart Agriculture Management Platform


**SmartFarm** is an enterprise-grade, multi-tenant smart agriculture management SaaS platform. It combines **LoRa-based IoT sensing**, **crop-aware automated environmental control**, **weather integration**, and **context-aware AI advisory services** to optimize farming efficiency, reduce resource waste, and enable data-driven agricultural decision-making.

---

## 📌 General Information

- **English Name:** SmartFarm: AI-powered Smart Agriculture Management Platform
- **Vietnamese Name:** SmartFarm: Nền tảng Quản lý Nông nghiệp Thông minh tích hợp AI
- **Field:** Software Engineering
- **Duration:** 09/2026 – 03/2027
- **Supervisors:** Đặng Ngọc Minh Đức & Thân Thị Ngọc Vân

---

## 📑 Table of Contents
1. [Key Features](#-key-features)
2. [System Architecture & Hierarchy](#2-system-architecture--hierarchy)
3. [User Roles & Access Scope](#3-user-roles--access-scope)
4. [Core Business Workflows](#4-core-business-workflows)
5. [Crop-Aware Intelligence](#5-crop-aware-intelligence)
6. [Hardware & IoT Infrastructure](#6-hardware--iot-infrastructure)
7. [AI Chatbot & Context-Aware Advisory](#7-ai-chatbot--context-aware-advisory)
8. [Technology Stack](#8-technology-stack)
9. [Project Deliverables](#9-project-deliverables)
10. [Work Packages & Roadmap](#10-work-packages--roadmap)
11. [Installation & Deployment](#11-installation--deployment)

---

## 🚀 Key Features

* **Multi-Tenant Architecture:** Secure tenant-level data isolation supporting multiple independent Farm Owners, Farms, and Fields on a single platform.
* **Crop-Aware & Growth Stage Monitoring:** Dynamic thresholding and control rules adjusted to specific crop profiles and growth stages (e.g., vegetative, flowering, fruiting).
* **LoRa-based Long-Range Sensing:** Low-power, long-distance sensor and actuator communication via LoRa Gateways and MQTT brokers.
* **Smart Environmental Actuation:** Automated and manual control for irrigation pumps, solenoid valves, ventilation fans, and grow lights.
* **Context-Aware AI Agricultural Assistant:** RAG-powered AI Chatbot integrating real-time sensor streams, weather forecasts, crop profiles, and user scope for tailored advice.
* **Weather API Integration:** Predictive irrigation pausing and environmental adjustments using forecast data.
* **Cross-Platform Management:** Web Portal for administrative and deep-analytics tasks; Mobile Application (Flutter) for field operations.

---

## 2. System Architecture & Hierarchy

### Multi-Tenant Organizational Structure

```text
SmartFarm Platform
│
├── Platform Admin
├── Platform Technician
│
└── Farm Owner (Tenant)
      │
      ├── Farmer / Farm Worker
      │
      └── One or More Farms
            │
            └── Fields
                  │
                  └── Zones
                        │
                        ├── Crop Profile (with Growth Stages)
                        │
                        └── Devices (LoRa Gateways ── Nodes ── Sensors/Actuators)
```

### System Architecture Diagram

```text
┌─────────────────────────────────────────────────────────┐
│                        Clients                          │
│     Web Management Portal      |     Flutter Mobile App │
└───────────────────────────┬─────────────────────────────┘
                            │ REST API / WebSockets
┌───────────────────────────▼─────────────────────────────┐
│                 ASP.NET Core Backend                    │
│ Auth | Tenant Manager | Farm Engine | IoT Ingestion     │
│ Alert Engine | Control Engine | Context Builder         │
└───────────────┬─────────────────────────┬───────────────┘
                │                         │
            MQTT Broker                 REST API
                │                         │
       ┌────────▼──────┐          ┌───────▼──────┐
       │ LoRa Gateway  │          │  AI Service  │
       └───────┬───────┘          └──────────────┘
               │ LoRa Wireless
        ┌──────┼──────┐
        ↓      ↓      ↓
      Node1  Node2  NodeN
        │      │      │
     Sensors & Actuators
```

---

## 3. User Roles & Access Scope

| Role | Domain Level | Primary Responsibilities | Scope & Permissions |
|---|---|---|---|
| **Platform Admin** | Platform | Manages tenants, system configurations, global monitoring, and subscriptions. | Full access to platform configuration and tenant accounts. |
| **Platform Technician** | Platform | Configures, provisions, diagnoses, and maintains IoT Gateways and sensor/actuator nodes. | Technical device management across assigned platform infrastructure. |
| **Farm Owner** | Tenant | Customer account holder. Manages farms, fields, zones, crop assignments, staff, and rules. | Full CRUD within their own tenant scope across all owned farms. |
| **Farmer / Farm Worker** | Tenant | Operations staff. Executes daily tasks, monitors zones, and controls actuators manually if authorized. | Restricted strictly to assigned farms, fields, or specific zones. |

> **Note:** "Farm Manager" is intentionally excluded from the project scope to maintain clear role boundaries.

---

## 4. Core Business Workflows

```text
┌────────────────────────────────────────────────────────────────────────┐
│  CF1: Tenant, Farm, Crop & IoT Setup                                   │
│  Farm Creation ➔ Zone Division ➔ Device Provisioning ➔ Profile Setup   │
└──────────────────────────────────┬─────────────────────────────────────┘
                                   │
                                   ▼
┌────────────────────────────────────────────────────────────────────────┐
│  CF2: Multi-Tenant Multi-Node Environmental Monitoring & Alerting     │
│  Real-Time Telemetry Data Ingestion ➔ Thresholding ➔ Notifications     │
└──────────────────────────────────┬─────────────────────────────────────┘
                                   │
                                   ▼
┌──────────────────────────────────┴─────────────────────────────────────┐
│                                                                        │
│  CF4: AI Advisory & Decision Support     CF3: Smart Environmental      │
│  RAG + LLM Context Search ──────────────> Control & Actuation          │
│  (Provides recommendations)              (Executes rule/approved actions)│
│                                                                        │
└──────────────────────────────────┬─────────────────────────────────────┘
                                   │
                                   ▼
┌────────────────────────────────────────────────────────────────────────┐
│  Environment Changes ➔ Loop Back to CF2 Sensing                        │
└────────────────────────────────────────────────────────────────────────┘
```

1. **CF1 – Setup & Provisioning:** Tenant creates organization hierarchy ($Farm \rightarrow Field \rightarrow Zone$). Technicians configure gateways and provision LoRa sensor nodes via Captive Portal.
2. **CF2 – Monitoring & Alerting:** Telemetry flows from nodes via LoRa to MQTT Broker to Backend. Readings are validated against crop-aware thresholds; alerts are dispatched instantly.
3. **CF3 – Smart Control & Actuation:** Controls environmental factors using scheduled rules, sensor triggers, weather forecasts, or user commands sent back over LoRa.
4. **CF4 – AI Advisory & Decision Support:** Context-aware LLM reasoning over live sensor data, weather data, and crop knowledge to guide the user.

---

## 5. Crop-Aware Intelligence

SmartFarm abandons generic global thresholding (e.g., fixed `soil_moisture < 40%`). Instead, it dynamically calculates conditions based on **Crop Profile** and **Current Growth Stage**.

```text
Incoming Sensor Reading (Soil, Temp, Humidity, Lux)
                         +
Crop Profile (e.g., Tomato) + Growth Stage (e.g., Flowering)
                         +
Weather API Forecast (e.g., Rain expected in 2 hours)
                         +
Configured Rule Engine
                         ↓
            [ Decision & Action Engine ]
     ┌───────────────────┴───────────────────┐
     ↓                                       ↓
Issue Recommended Alert / Advice     Execute/Pause Actuation (Pump/Fan)
```

---

## 6. Hardware & IoT Infrastructure

### Hardware Components
* **Microcontrollers:** ESP32-based LoRa Nodes & Gateways.
* **Sensors:** Soil Moisture, Ambient Temperature, Air Humidity, Light Intensity (Lux), Rain Sensor, Water Level.
* **Actuators:** Water Pumps, Solenoid Valves, Ventilation Fans, Grow Lights.

### Communication Flow
1. **Sensors** read environmental parameters.
2. **LoRa Nodes** transmit payload over long-range wireless protocol to **LoRa Gateway**.
3. **Gateway** bridges LoRa frames to **MQTT** over Wi-Fi/Ethernet to the cloud broker.
4. **Backend Ingestion Engine** parses JSON payload, enforces tenant context, logs time-series data, and triggers rules.

---

## 7. AI Chatbot & Context-Aware Advisory

The integrated AI assistant utilizes **Retrieval-Augmented Generation (RAG)** combined with Large Language Models (LLM / Gemini API) to answer operational questions.

```text
User Question ("Should I water Zone A today?")
                         ↓
Context Aggregator (Injects Tenant ID, Zone Data, Stage, Weather, Soil Moisture)
                         ↓
     RAG Vector Engine + Agricultural Knowledge Base
                         ↓
           LLM Reasoner (Gemini Service)
                         ↓
Contextual Advice ("Zone A soil moisture is 32%, but rain is forecasted in 3 hours. Pausing irrigation is recommended.")
```

> **Safety Rule:** AI acts as an advisory system. Direct actuation execution requires human confirmation or explicit rule-engine integration.

---

## 8. Technology Stack

* **Web Application:** React.js / Web Portal (Responsive Dashboard UI)
* **Mobile Application:** Flutter (iOS & Android)
* **Backend Framework:** ASP.NET Core (RESTful API & WebSockets)
* **Database & Time-Series:** PostgreSQL with TimeScaleDB extension / Entity Framework Core
* **IoT Protocols:** LoRa, LoRaWAN, MQTT
* **Security & Auth:** JWT (JSON Web Tokens), Multi-Tenant RBAC
* **DevOps & Containers:** Docker, Docker Compose
* **AI & LLM Services:** Gemini API, RAG, RESTful AI Gateway
* **External APIs:** Weather API (OpenWeather / WeatherAPI)

---

## 9. Project Deliverables

1. **SmartFarm Web Management Portal**
2. **SmartFarm Cross-Platform Mobile Application (Flutter)**
3. **Multi-Tenant SaaS Core & RBAC Module**
4. **Device & IoT Gateway Provisioning Module**
5. **Real-time Environmental Monitoring Engine**
6. **Smart Irrigation & Actuation Module**
7. **Crop Profile & Growth Stage Library**
8. **Context-Aware AI Agricultural Assistant**
9. **Analytics, Reporting & PDF/Excel Export Module**
10. **Containerized Deployment Package (Docker)**
11. **Technical & System Documentation**

---

## 10. Work Packages & Roadmap

* **WP1 – Requirements Analysis & Architecture Design (09/2026 - 10/2026)**
  * Stakeholder requirements, RBAC definition, Multi-tenant DB design, API specs.
* **WP2 – IoT Ingestion & Farm Core Services (10/2026 - 11/2026)**
  * MQTT pipeline, LoRa integration, Farm/Field/Zone management, Monitoring dashboard.
* **WP3 – Mobile Client & AI Integration (11/2026 - 12/2026)**
  * Flutter UI development, Gemini AI Assistant integration, Weather API hookup.
* **WP4 – Analytics & Smart Actuation Engine (12/2026 - 01/2027)**
  * Automated control rules, environmental trend analytics, report export capabilities.
* **WP5 – Testing, Hardening & Deployment (01/2027 - 03/2027)**
  * Tenant isolation testing, hardware end-to-end integration, Docker packaging, final project defense.

---

## 11. Installation & Deployment

### Prerequisites
* Docker Engine `^24.0` & Docker Compose `^2.20`
* .NET 8.0 SDK (for local backend development)
* Flutter SDK `^3.19` (for mobile app build)
* Node.js `^20` (for web frontend build)

### Quickstart using Docker Compose

1. **Clone Repository**
   ```bash
   git clone https://github.com/your-org/smartfarm.git
   cd smartfarm
   ```

2. **Configure Environment Variables**
   Copy the example `.env` file and supply your database keys, MQTT credentials, and AI service API keys:
   ```bash
   cp .env.example .env
   ```

3. **Spin Up Containers**
   ```bash
   docker-compose up -d --build
   ```

4. **Verify Running Services**
   * Web Portal: `http://localhost:3000`
   * REST API & Swagger UI: `http://localhost:5000/swagger`
   * MQTT Broker: `localhost:1883`

