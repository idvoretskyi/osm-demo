# OCM Demo Playground Flow Diagram

This document contains mermaid diagrams that visualize the complete OCM demo playground workflow, from basic component creation to advanced Kubernetes deployments.

## 🌊 Complete Learning Flow

```mermaid
graph TD
    A[🚀 Start: OCM Demo Playground] --> B[📋 Prerequisites Check]
    B --> C[🛠️ Environment Setup]
    C --> D{Choose Learning Path}
    
    D --> E[📝 01-Basic Examples]
    D --> F[🚀 02-Transport Examples] 
    D --> G[🔐 03-Signing Examples]
    D --> H[☸️ 04-K8s Deployment]
    
    %% Basic Examples Flow
    E --> E1[Hello World Component]
    E1 --> E2[Multi-Resource Component]
    E2 --> E3[Metadata & Labels]
    E3 --> F
    
    %% Transport Examples Flow
    F --> F1[Local to OCI Registry]
    F1 --> F2[Cross-Registry Replication]
    F2 --> F3[Offline Transport (CTF)]
    F3 --> G
    
    %% Signing Examples Flow
    G --> G1[Key Generation]
    G1 --> G2[Component Signing]
    G2 --> G3[Signature Verification]
    G3 --> H
    
    %% Kubernetes Deployment Flow
    H --> H1[Kind Cluster Setup]
    H1 --> H2[OCM K8s Toolkit]
    H2 --> H3[Component Deployment]
    H3 --> I[🎯 Production Ready]
    
    %% Utility Integration
    J[🛠️ OCM Utils] --> E
    J --> F
    J --> G
    J --> H
    
    style A fill:#e1f5fe
    style I fill:#e8f5e8
    style J fill:#fff3e0
```

## 🔄 Component Lifecycle Flow

```mermaid
graph LR
    subgraph "Development"
        A1[📝 Create Source] --> A2[📋 Component Descriptor]
        A2 --> A3[📦 Package Resources]
    end
    
    subgraph "Security"
        B1[🔑 Generate Keys] --> B2[✍️ Sign Component]
        B2 --> B3[✅ Verify Signature]
    end
    
    subgraph "Transport"
        C1[📂 Local Archive] --> C2[🚀 Push to Registry]
        C2 --> C3[🔄 Cross-Registry]
        C3 --> C4[💾 Offline Bundle]
    end
    
    subgraph "Deployment"
        D1[☸️ K8s Cluster] --> D2[🛠️ OCM Toolkit]
        D2 --> D3[📋 Apply Manifests]
        D3 --> D4[🌐 Running App]
    end
    
    A3 --> B1
    B3 --> C1
    C4 --> D1
    
    style A1 fill:#e3f2fd
    style B2 fill:#fce4ec
    style C2 fill:#e8f5e8
    style D4 fill:#f3e5f5
```

## 🏗️ Architecture and Tool Integration

```mermaid
graph TB
    subgraph "OCM Core"
        OCM[OCM CLI]
        CD[Component Descriptor]
        R[Resources]
    end
    
    subgraph "Storage Backends"
        LA[Local Archive]
        OCI[OCI Registry]
        CTF[Common Transport Format]
    end
    
    subgraph "Security Layer"
        KEYS[RSA Keys]
        SIG[Digital Signatures]
        TRUST[Trust Policies]
    end
    
    subgraph "Kubernetes Integration"
        KIND[Kind Cluster]
        K8S[Kubernetes API]
        FLUX[FluxCD]
        KRO[Kro Operator]
    end
    
    subgraph "Demo Examples"
        BASIC[01-Basic Examples]
        TRANSPORT[02-Transport Examples]
        SIGNING[03-Signing Examples]
        K8SDEPLOY[04-K8s Deployment]
    end
    
    %% Core connections
    OCM --> CD
    CD --> R
    
    %% Storage connections
    OCM --> LA
    OCM --> OCI
    OCM --> CTF
    
    %% Security connections
    OCM --> KEYS
    KEYS --> SIG
    SIG --> TRUST
    
    %% K8s connections
    KIND --> K8S
    K8S --> FLUX
    K8S --> KRO
    
    %% Example connections
    BASIC --> OCM
    TRANSPORT --> OCI
    SIGNING --> SIG
    K8SDEPLOY --> K8S
    
    style OCM fill:#1976d2,color:#fff
    style K8S fill:#326ce5,color:#fff
    style OCI fill:#ff7043,color:#fff
    style SIG fill:#7b1fa2,color:#fff
```

## 📚 Detailed Example Flows

### 01-Basic Examples Flow

```mermaid
flowchart TD
    B1[🏁 Start Basic Examples] --> B2[📝 Hello World]
    B2 --> B3{Create Component Archive}
    B3 --> B4[Add Text Resource]
    B4 --> B5[Inspect Component]
    B5 --> B6[Push to Registry]
    
    B6 --> B7[📦 Multi-Resource Example]
    B7 --> B8[Add Config Files]
    B8 --> B9[Add Documentation]
    B9 --> B10[Add Scripts]
    B10 --> B11[Package Complete Component]
    
    B11 --> B12[✅ Basic Examples Complete]
    
    style B1 fill:#e3f2fd
    style B12 fill:#e8f5e8
```

### 02-Transport Examples Flow

```mermaid
flowchart LR
    T1[🚀 Transport Examples] --> T2[Local Archive]
    T2 --> T3[OCI Registry A]
    T3 --> T4[OCI Registry B]
    T4 --> T5[Common Transport Format]
    T5 --> T6[Air-Gapped Environment]
    T6 --> T7[Target Registry]
    
    T2 -.->|"Local to OCI"| T3
    T3 -.->|"Cross-Registry"| T4
    T4 -.->|"Export CTF"| T5
    T5 -.->|"Physical Transport"| T6
    T6 -.->|"Import CTF"| T7
    
    style T1 fill:#fff3e0
    style T7 fill:#e8f5e8
```

### 03-Signing Examples Flow

```mermaid
flowchart TD
    S1[🔐 Signing Examples] --> S2[Generate RSA Keys]
    S2 --> S3[Create Component]
    S3 --> S4[Sign with Production Key]
    S4 --> S5[Sign with Dev Key]
    S5 --> S6[Transport to Registry]
    S6 --> S7[Verify Signatures]
    S7 --> S8{Signature Valid?}
    S8 -->|Yes| S9[✅ Component Trusted]
    S8 -->|No| S10[❌ Reject Component]
    
    style S1 fill:#fce4ec
    style S9 fill:#e8f5e8
    style S10 fill:#ffebee
```

### 04-K8s Deployment Flow

```mermaid
flowchart TD
    K1[☸️ K8s Deployment] --> K2[Setup Kind Cluster]
    K2 --> K3[Install NGINX Ingress]
    K3 --> K4[Install Flux]
    K4 --> K5[Install OCM CRDs]
    
    K5 --> K6[Create OCM Component]
    K6 --> K7[Package K8s Manifests]
    K7 --> K8[Push to Registry]
    
    K8 --> K9[Create ComponentVersion CR]
    K9 --> K10[Create OCMConfiguration CR]
    K10 --> K11[Extract Manifests]
    K11 --> K12[Apply to Cluster]
    
    K12 --> K13{Deployment Ready?}
    K13 -->|Yes| K14[🌐 App Running]
    K13 -->|No| K15[Debug & Retry]
    K15 --> K12
    
    style K1 fill:#e8eaf6
    style K14 fill:#e8f5e8
```

## 🛠️ Utility Scripts Integration

```mermaid
graph LR
    subgraph "OCM Utils Commands"
        U1[setup]
        U2[registry start/stop/reset]
        U3[status]
        U4[list-components]
        U5[run-all]
        U6[cleanup]
    end
    
    subgraph "Core Functions"
        F1[Environment Setup]
        F2[Registry Management]
        F3[Health Checks]
        F4[Component Discovery]
        F5[Automation]
        F6[Cleanup Operations]
    end
    
    subgraph "Examples"
        E1[01-Basic]
        E2[02-Transport]
        E3[03-Signing]
        E4[04-K8s-Deploy]
    end
    
    U1 --> F1
    U2 --> F2
    U3 --> F3
    U4 --> F4
    U5 --> F5
    U6 --> F6
    
    F1 --> E1
    F2 --> E2
    F5 --> E3
    F3 --> E4
    
    style U5 fill:#fff3e0
    style F5 fill:#e8f5e8
```

## 🎯 Success Metrics and Outcomes

```mermaid
graph TD
    subgraph "Learning Outcomes"
        L1[Component Creation ✅]
        L2[Transport Mechanisms ✅]
        L3[Security & Signing ✅]
        L4[K8s Integration ✅]
    end
    
    subgraph "Technical Skills"
        T1[OCM CLI Proficiency]
        T2[Registry Operations]
        T3[Cryptographic Signing]
        T4[Kubernetes Deployment]
    end
    
    subgraph "Production Readiness"
        P1[GitOps Workflows]
        P2[Security Best Practices]
        P3[Multi-Environment Deployment]
        P4[Troubleshooting Skills]
    end
    
    L1 --> T1
    L2 --> T2
    L3 --> T3
    L4 --> T4
    
    T1 --> P1
    T2 --> P2
    T3 --> P3
    T4 --> P4
    
    style P4 fill:#e8f5e8
```

## Usage

To view these diagrams:

1. **In GitHub**: The diagrams will render automatically in GitHub's markdown viewer
2. **In VS Code**: Install the "Mermaid Preview" extension
3. **Online**: Copy the mermaid code to [mermaid.live](https://mermaid.live)
4. **Local**: Use mermaid-cli: `npx @mermaid-js/mermaid-cli -i ocm-demo-flow.md -o ocm-demo-flow.html`

## Interactive Exploration

Each diagram section corresponds to specific examples in the playground:

- **Learning Flow**: Follow the recommended path through `examples/`
- **Component Lifecycle**: Understand the complete journey from creation to deployment
- **Architecture**: See how tools integrate in the OCM ecosystem
- **Example Flows**: Detailed walkthrough of each example section
- **Utility Integration**: How helper scripts support the learning experience
