// Dashboard configuration
const CONFIG = {
    refreshInterval: 10000, // 10 seconds
    apiPath: '/dashboard/api/',
    endpoints: {
        status: 'status.json',
        stats: 'stats.json',
        network: 'network.json',
        topology: 'topology.json'
    }
};

// State
let autoRefresh = true;
let refreshTimer = null;

// Utility functions
function formatUptime(startedAt) {
    if (!startedAt || startedAt === 'null' || startedAt === 'unknown') {
        return 'N/A';
    }

    try {
        const started = new Date(startedAt);
        const now = new Date();
        const diff = now - started;

        const hours = Math.floor(diff / 3600000);
        const minutes = Math.floor((diff % 3600000) / 60000);

        if (hours > 24) {
            const days = Math.floor(hours / 24);
            return `${days}d ${hours % 24}h`;
        }
        return `${hours}h ${minutes}m`;
    } catch (e) {
        return 'N/A';
    }
}

function getContainerClass(name) {
    if (name.startsWith('pc')) return 'container-pc';
    if (name.startsWith('router')) return 'container-router';
    if (name === 'server_web') return 'container-server';
    if (name === 'dnsmasq') return 'container-dns';
    return '';
}

function updateLastUpdateTime() {
    const now = new Date();
    const timeString = now.toLocaleTimeString();
    document.getElementById('last-update').textContent = `Last update: ${timeString}`;
}

// API fetch functions
async function fetchJSON(endpoint) {
    try {
        const response = await fetch(CONFIG.apiPath + endpoint);
        if (!response.ok) {
            throw new Error(`HTTP error! status: ${response.status}`);
        }
        return await response.json();
    } catch (error) {
        console.error(`Error fetching ${endpoint}:`, error);
        return null;
    }
}

// Update container status table
async function updateContainerStatus() {
    const data = await fetchJSON(CONFIG.endpoints.status);
    const tbody = document.getElementById('status-tbody');

    if (!data || !data.containers) {
        tbody.innerHTML = '<tr><td colspan="4" class="error-message">Failed to load status data</td></tr>';
        return;
    }

    let html = '';
    data.containers.forEach(container => {
        const statusClass = container.status === 'running' ? 'status-running' : 'status-stopped';
        const healthClass = container.health === 'healthy' ? 'health-healthy' :
                           container.health === 'unhealthy' ? 'health-unhealthy' :
                           'health-no-check';

        const uptime = formatUptime(container.started_at);

        html += `
            <tr class="fade-in">
                <td><span class="container-name ${getContainerClass(container.name)}">${container.name}</span></td>
                <td><span class="status-badge ${statusClass}">${container.status}</span></td>
                <td><span class="status-badge ${healthClass}">${container.health}</span></td>
                <td>${uptime}</td>
            </tr>
        `;
    });

    tbody.innerHTML = html;
}

// Update resource stats table
async function updateResourceStats() {
    const data = await fetchJSON(CONFIG.endpoints.stats);
    const tbody = document.getElementById('stats-tbody');

    if (!data || !data.stats) {
        tbody.innerHTML = '<tr><td colspan="4" class="error-message">Failed to load stats data</td></tr>';
        return;
    }

    if (data.stats.length === 0) {
        tbody.innerHTML = '<tr><td colspan="4" class="loading">No containers running</td></tr>';
        return;
    }

    let html = '';
    data.stats.forEach(stat => {
        html += `
            <tr class="fade-in">
                <td><span class="container-name ${getContainerClass(stat.name)}">${stat.name}</span></td>
                <td>${stat.cpu}</td>
                <td>${stat.memory}</td>
                <td>${stat.network}</td>
            </tr>
        `;
    });

    tbody.innerHTML = html;
}

// Update network info table
async function updateNetworkInfo() {
    const data = await fetchJSON(CONFIG.endpoints.network);
    const tbody = document.getElementById('network-tbody');

    if (!data || !data.networks) {
        tbody.innerHTML = '<tr><td colspan="3" class="error-message">Failed to load network data</td></tr>';
        return;
    }

    let html = '';
    data.networks.forEach(network => {
        html += `
            <tr class="fade-in">
                <td><strong>${network.name}</strong></td>
                <td>${network.subnet}</td>
                <td>${network.containers}</td>
            </tr>
        `;
    });

    tbody.innerHTML = html;
}

// Update topology display
async function updateTopology() {
    const data = await fetchJSON(CONFIG.endpoints.topology);
    const container = document.getElementById('topology-info');

    if (!data || !data.zones) {
        container.innerHTML = '<div class="error-message">Failed to load topology data</div>';
        return;
    }

    let html = '';
    data.zones.forEach(zone => {
        const hosts = zone.hosts.join(', ');
        html += `
            <div class="topology-item fade-in">
                <h3>${zone.name}</h3>
                <p><strong>Subnet:</strong> ${zone.subnet}</p>
                <p><strong>Gateway:</strong> ${zone.gateway}</p>
                <p class="topology-hosts"><strong>Hosts:</strong> ${hosts}</p>
            </div>
        `;
    });

    container.innerHTML = html;
}

// Update all dashboard data
async function updateDashboard() {
    try {
        await Promise.all([
            updateContainerStatus(),
            updateResourceStats(),
            updateNetworkInfo(),
            updateTopology()
        ]);
        updateLastUpdateTime();
    } catch (error) {
        console.error('Error updating dashboard:', error);
    }
}

// Setup auto-refresh
function setupAutoRefresh() {
    if (autoRefresh) {
        refreshTimer = setInterval(updateDashboard, CONFIG.refreshInterval);
    }
}

function toggleAutoRefresh() {
    autoRefresh = !autoRefresh;
    const statusSpan = document.querySelector('#auto-refresh .status-active');

    if (autoRefresh) {
        statusSpan.textContent = 'ON';
        statusSpan.classList.add('pulse');
        setupAutoRefresh();
    } else {
        statusSpan.textContent = 'OFF';
        statusSpan.classList.remove('pulse');
        if (refreshTimer) {
            clearInterval(refreshTimer);
            refreshTimer = null;
        }
    }
}

// Keyboard shortcuts
document.addEventListener('keydown', (e) => {
    // Press 'r' to refresh
    if (e.key === 'r' && !e.ctrlKey && !e.metaKey) {
        e.preventDefault();
        updateDashboard();
    }

    // Press 'a' to toggle auto-refresh
    if (e.key === 'a' && !e.ctrlKey && !e.metaKey) {
        e.preventDefault();
        toggleAutoRefresh();
    }
});

// Initialize dashboard on page load
document.addEventListener('DOMContentLoaded', () => {
    console.log('Docker Network Playground Dashboard');
    console.log('Keyboard shortcuts: r = refresh, a = toggle auto-refresh');

    // Initial load
    updateDashboard();

    // Setup auto-refresh
    setupAutoRefresh();

    // Add pulse animation to auto-refresh indicator
    document.querySelector('#auto-refresh .status-active').classList.add('pulse');
});

// Handle visibility change (pause updates when tab is hidden)
document.addEventListener('visibilitychange', () => {
    if (document.hidden) {
        if (refreshTimer) {
            clearInterval(refreshTimer);
            refreshTimer = null;
        }
    } else if (autoRefresh) {
        updateDashboard();
        setupAutoRefresh();
    }
});
