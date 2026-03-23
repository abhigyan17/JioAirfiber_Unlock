import pandas as pd
import matplotlib.pyplot as plt
import seaborn as sns
import matplotlib.dates as mdates
from matplotlib.patches import Patch

# Load CSV and parse the timestamp column
df = pd.read_csv("statistics.csv", parse_dates=["timestamp"])

# Convert relevant columns to numeric if needed
df["rsrp"] = pd.to_numeric(df["rsrp"], errors='coerce')
df["sinr"] = pd.to_numeric(df["sinr"], errors='coerce')

# Set timestamp as index
df.set_index("timestamp", inplace=True)

# Resample data per hour:
# - For continuous metrics, use the mean.
# - For PCI (a categorical value with little variation), take the first value in each period.
df_hourly = pd.DataFrame({
    'rsrp': df['rsrp'].resample("1h").mean(),
    'sinr': df['sinr'].resample("1h").mean(),
    'pci': df['pci'].resample("1h").first()
})

# Create a mapping for PCI values to colors using a pastel palette
unique_pci = df_hourly['pci'].dropna().unique()
pci_colors = sns.color_palette("pastel", len(unique_pci))
pci_color_map = dict(zip(unique_pci, pci_colors))

# Create the plot with two y-axes
fig, ax1 = plt.subplots(figsize=(14, 6))
ax2 = ax1.twinx()

# Shade the background for each hourly interval based on the PCI value
for timestamp, pci_value in df_hourly['pci'].items():
    if pd.notnull(pci_value):
        start = timestamp
        end = start + pd.Timedelta(hours=1)
        ax1.axvspan(start, end, color=pci_color_map[pci_value], alpha=0.15)

# Plot the RSRP (primary y-axis) and SINR (secondary y-axis)
sns.lineplot(ax=ax1, data=df_hourly, x=df_hourly.index, y="rsrp", 
             label="RSRP (dBm)", linewidth=2.5, color="royalblue")
sns.lineplot(ax=ax2, data=df_hourly, x=df_hourly.index, y="sinr", 
             label="SINR (dB)", linewidth=2.5, color="darkorange")

# Configure the x-axis: tick marks every 60 minutes with date & time formatting
locator = mdates.MinuteLocator(interval=480)
formatter = mdates.DateFormatter("%Y-%m-%d %H:%M")
ax1.xaxis.set_major_locator(locator)
ax1.xaxis.set_major_formatter(formatter)
plt.setp(ax1.get_xticklabels(), rotation=45)

# Set axis labels and title
ax1.set_xlabel("Time", fontsize=12)
ax1.set_ylabel("RSRP (dBm)", fontsize=12)
ax2.set_ylabel("SINR (dB)", fontsize=12)
plt.title("Hourly Variation of Signal Strength (RSRP) & SINR with PCI Shading", fontsize=14, fontweight="bold")

# Create legends:
# 1. Get the legend for the line plots.
lines_handles, lines_labels = ax1.get_legend_handles_labels()
legend_lines = ax1.legend(lines_handles, lines_labels, loc='upper left')

# 2. Create a custom legend for PCI shading using patches.
pci_patches = [Patch(facecolor=color, label=f"PCI: {pci}") for pci, color in pci_color_map.items()]
legend_pci = ax1.legend(handles=pci_patches, loc='upper right', title="PCI Shading")

# Ensure both legends are displayed.
ax1.add_artist(legend_lines)

plt.grid(True, linestyle="--", alpha=0.6)
plt.tight_layout()
plt.show()
