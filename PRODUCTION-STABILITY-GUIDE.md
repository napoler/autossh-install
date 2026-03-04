# 🛡️ SSH/AutoSSH Production Stability Guide
## Enterprise-Grade Configurations for Critical Infrastructure

### 🔍 Overview
Optimized configurations for maximum stability in production environments with unreliable network conditions, especially for satellite, industrial IoT, and remote location deployments. These configurations prioritize resiliency over resource efficiency, suitable for mission-critical infrastructure where connection continuity is paramount.

---

## 📋 Table of Contents
1. [Maximum Stability Configurations](#maximum-stability-configurations)
2. [Total Timeout Calculations](#total-timeout-calculations)
3. [Satellite/Remote Deployment Patterns](#satellite--remote-location-deployments)
4. [Production Configuration Templates](#production-configuration-templates)
5. [Military-Grade Enterprise Setup](#military-grade-enterprise-setup)

---

## 🎯 Maximum Stability Configurations

### Configuration Type A: High Resiliency (Recommended for critical infrastructure)
```ini
# Total timeout = 30s x 60 = 1,800 seconds (30 minutes)
-o ServerAliveInterval=30
-o ServerAliveCountMax=60
-o TCPKeepAlive=yes
-o ConnectTimeout=180
-o ConnectionAttempts=10
-o IdentitiesOnly=yes
-o StrictHostKeyChecking=yes
-o Compression=no
-o ClearAllForwardings=yes
-o ServerAliveInterval=30
-o ServerAliveCountMax=60
```

### Configuration Type B: Ultra Conservative (Satellite/High Latency)
```ini
# Total timeout = 60s x 120 = 7,200 seconds (120 minutes / 2 hours)
-o ServerAliveInterval=60
-o ServerAliveCountMax=120
-o TCPKeepAlive=yes
-o ConnectTimeout=300
-o ConnectionAttempts=15
-o Ciphers=aes256-ctr,aes192-ctr,aes128-ctr
-o KexAlgorithms=diffie-hellman-group14-sha256
-o MACs=hmac-sha2-256,hmac-sha2-512
-o CheckHostIP=yes
```

### Configuration Type C: Extreme Stability (Remote/IoT Deployments)
```ini
# Total timeout = 120s x 90 = 10,800 seconds (180 minutes / 3 hours) 
-o ServerAliveInterval=120
-o ServerAliveCountMax=90
-o TCPKeepAlive=yes
-o ConnectTimeout=600
-o ConnectionAttempts=20
-o GlobalKnownHostsFile=/etc/ssh/ssh_known_hosts_custom
-o PasswordAuthentication=no
-o PreferredAuthentications=publickey
```

---

## ⏰ Total Timeout Calculations

### Formula: 
**Total Connection Timeout = ServerAliveInterval × ServerAliveCountMax**

| Configuration Level | Interval (s) | CountMax | Total Timeout | Use Case |
|-------------------|--------------|----------|---------------|----------|
| Conservative | 30 | 10 | 5 minutes | Standard unstable networks |
| Aggressive | 30 | 60 | 30 minutes | Production critical systems |
| Satellite | 60 | 120 | 120 minutes | High latency/satellite links |
| Extreme | 120 | 90 | 180 minutes | Remote/IoT deployments |

### Key Timeout Components:
1. **Primary Timeout**: ServerAlive settings (above table)
2. **Connection Attempt**: ConnectTimeout (180-600s for retry attempts)
3. **AutoSSH Monitoring**: Controlled by AutoSSH parameters below

---

## 🛰️ Satellite & Remote Location Deployments

### Common Satellite Configuration Pattern:
```bash
autossh -M 0 -N -T \
    -o ServerAliveInterval=60 \
    -o ServerAliveCountMax=120 \
    -o TCPKeepAlive=yes \
    -o ConnectTimeout=300 \
    -o ConnectionAttempts=15 \
    -o BatchMode=yes \
    -o ControlPersist=30m \
    -o ControlMaster=auto \
    -o UseRoaming=no \
    -o ExitOnForwardFailure=yes \
    -L ${LOCAL_PORT}:localhost:${REMOTE_PORT} \
    ${USER}@${HOST} -p ${PORT}
```

### Systemd Service Template for Remote Deployments:
```ini
[Unit]
Description=Production AutoSSH Service - %I [Satellite Configuration]
Wants=network-online.target
After=network-online.target

[Service]
Type=simple
User=%i
Group=%i
Environment=AUTOSSH_PIDFILE=/var/run/autossh_%i.pid
Environment=AUTOSSH_POLL=60
Environment=AUTOSSH_GATETIME=0
Environment=AUTOSSH_FIRST_POLL=30
ExecStartPre=/bin/sleep 15
ExecStart=/usr/bin/autossh -M 0 -N -T \\
    -o ServerAliveInterval=90 \\
    -o ServerAliveCountMax=100 \\
    -o TCPKeepAlive=yes \\
    -o ConnectTimeout=360 \\
    -o ConnectionAttempts=25 \\
    -o BatchMode=yes \\
    -o ExitOnForwardFailure=yes \\
    -o UseRoaming=no \\
    -o ServerAliveInterval=90 \\
    -o ServerAliveCountMax=100 \\
    -i ${SSH_KEY} \\
    -L ${SERVICE_PORT}:localhost:${INTERNAL_PORT} \\
    ${REMOTE_USER}@${REMOTE_HOST}

Restart=always
RestartSec=30
KillMode=process

# Security settings  
NoNewPrivileges=true
RestrictAddressFamilies=AF_INET AF_INET6
RestrictRealtime=true
LockPersonality=true
SystemCallFilter=~@mount @swap

# Performance settings
OOMScoreAdjust=-1000
IOSchedulingClass=3
Nice=-20

[Install]
WantedBy=multi-user.target
```

---

## 🏭 Production Configuration Templates

### Standard Production (Medium-Latency Stable):
```ini
# STABLE PRODUCTION CONFIG
-o ServerAliveInterval=45              # Moderate frequency check
-o ServerAliveCountMax=40              # Allow for 30 min total timeout  
-o TCPKeepAlive=yes                    # Enable TCP layer keep-alive
-o ConnectTimeout=240                  # 4 min connect timeout
-o ConnectionAttempts=12               # Retry multiple times
-o ExitOnForwardFailure=yes           # Exit if tunnel fails
-o UseRoaming=no                      # Disable roaming features
-o RequestTTY=no                      # Don't request terminal allocation
```
**Total Timeout**: 45 × 40 = 1,800 seconds = 30 minutes

### Aggressive Production (High-Importance Critical):
```ini
# CRITICAL PRODUCTION CONFIG  
-o ServerAliveInterval=20              # High frequency checking
-o ServerAliveCountMax=90              # Long tolerance window
-o TCPKeepAlive=yes                    # Enable TCP layer keep-alive
-o ConnectTimeout=180                  # 3 min connect timeout
-o ConnectionAttempts=15               # Multiple connection attempts
-o ExitOnForwardFailure=yes           # Fail fast if tunnel fails
-o UsePrivilegedPort=yes              # Try privileged ports if needed
-o CheckHostIP=yes                   # Verify IP of host key
```
**Total Timeout**: 20 × 90 = 1,800 seconds = 30 minutes  
**Frequency**: Every 20 seconds for early detection

### Satellite/High-Latency Configuration:
```ini
# SATELLITE/LONG-DISTANCE PRODUCTION CONFIG
-o ServerAliveInterval=120             # Reduced checking frequency  
-o ServerAliveCountMax=75              # Large allowance for long delays
-o TCPKeepAlive=yes                    # Enable TCP layer keep-alive  
-o ConnectTimeout=600                  # 10 min connection timeout
-o ConnectionAttempts=20               # Extended retry window
-o Compression=yes                    # Compress data for high latency
-o TcpCongestionControl=cubic         # Better throughput over satellite
```
**Total Timeout**: 120 × 75 = 9,000 seconds = 150 minutes = 2.5 hours

---

## 🏗️ Military-Grade Enterprise Setup

### Mission-Critical Configuration:
```ini
# MILITARY-GRADE ENTERPRISE CONFIGURATION
-o ServerAliveInterval=60              # Consistent checking interval
-o ServerAliveCountMax=180             # 3-hour total timeout tolerance
-o TCPKeepAlive=yes                    # Dual-layer keep-alive
-o ConnectTimeout=600                  # Extended connection timeout
-o ConnectionAttempts=30               # Maximum retry attempts
-o Ciphers=aes256-gcm@openssh.com,chacha20-poly1305@openssh.com,aes256-ctr
-o MACs=hmac-sha2-512-etm@openssh.com,hmac-sha2-256-etm@openssh.com
-o KexAlgorithms=curve25519-sha256,diffie-hellman-group16-sha512
-o HostKeyAlgorithms=rsa-sha2-512,rsa-sha2-256,ecdsa-sha2-nistp521
-o LogLevel VERBOSE                    # Detailed logging for monitoring
-o AddKeysToAgent=yes                 # Cache keys to avoid delays
-o UpdateHostKeys=yes                 # Security key updates
-o UseKeychain=yes                    # macOS keychain integration
```
**Total Timeout**: 60 × 180 = 10,800 seconds = 180 minutes = 3 hours

### AutoSSH Environment Variables for Critical Systems:
```bash
# CRITICAL INFRASTRUCTURE AUTOSSH SETTINGS
AUTOSSH_EXEC=/usr/bin/ssh
AUTOSSH_GATETIME=0                     # Immediate monitoring start
AUTOSSH_POLL=120                       # Check every 2 mins
AUTOSSH_FIRST_POLL=60                  # First monitor after 1 min  
AUTOSSH_DEBUG=1                        # Enable debug output
AUTOSSH_LOGLEVEL=7                     # Maximum verbose logging
AUTOSSH_PATH=/usr/bin/ssh
AUTOSSH_PIDFILE=/var/run/autossh.pid
AUTOSSH_WAITTIME=60                    # Wait time between restarts
AUTOSSH_MAXSTART=30                    # Max restart attempts in period
```

### Network-Aware Configuration:
```ini
# ADAPTIVE CONFIGURATION FOR CHANGING NETWORK CONDITIONS
ServerAliveInterval=30        # Start conservative, adjust as needed
ServerAliveCountMax=60        # Reasonable timeout window
IPQoS throughput             # Prioritize throughput for stable connections
TCPKeepAlive=yes             # Enable system-level TCP keep-alive
```

---

## 📝 Implementation Notes

### Critical Success Factors:
1. **ServerAliveInterval × ServerAliveCountMax** sets the maximum connection dead time before termination
2. Setting higher `ConnectionAttempts` helps with spotty connections
3. `TCPKeepAlive=yes` provides additional protection layer at TCP vs SSH level
4. `ConnectTimeout` setting impacts initial connection failure speed
5. Combine with AutoSSH polling configuration for maximum reliability

### Monitoring Recommendations:
- Monitor the total connection timeout vs. your expected maximum network downtime window
- Adjust configurations based on observed network behavior and outage patterns
- Regular testing under simulated network stress conditions

### Configuration Priority:
```
1. AutoSSH Service Monitoring 
2. SSH Keep-Alive Settings
3. TCP Keep-Alive Settings  
4. Connection Retry Settings
5. Additional Security Settings
```

The combination of service-level (AutoSSH) and connection-level (SSH) monitoring provides maximum redundancy for mission-critical deployments.