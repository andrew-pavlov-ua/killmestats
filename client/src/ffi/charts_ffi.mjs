const ink = "#2f2933";
const pink = "#ffaff3";
const cyan = "#a6f0fc";
const pinkLine = "#b832a5";
const cyanLine = "#117f94";
const axis = "rgba(47, 41, 51, 0.32)";
const percentFormatter = new Intl.NumberFormat(undefined, {
  maximumFractionDigits: 1,
  style: "percent",
});
const timeFormatter = new Intl.DateTimeFormat(undefined, {
  hour: "2-digit",
  minute: "2-digit",
});
const relativeTimeFormatter = new Intl.RelativeTimeFormat(undefined, {
  numeric: "auto",
});

function labelsFor(pointCount, timestamps) {
  const labels = timestamps.map((timestamp) =>
    timeFormatter.format(new Date(timestamp)),
  );

  // Cached points have timestamps; the appended live sample is labeled “now”.
  while (labels.length < pointCount) {
    labels.push(relativeTimeFormatter.format(0, "second"));
  }

  return labels;
}

export function renderChart(id, cpuHistory, ramHistory, timestamps) {
  const cpuValues = Array.from(cpuHistory);
  const ramValues = Array.from(ramHistory);
  const timestampValues = Array.from(timestamps);

  requestAnimationFrame(() => {
    const Chart = globalThis.Chart;
    if (!Chart) {
      console.error(
        "Chart.js failed to load; verify /chart.umd.min.js is available.",
      );
      return;
    }

    const canvas = document.getElementById(id);
    if (!(canvas instanceof HTMLCanvasElement)) return;

    const pointCount = Math.max(cpuValues.length, ramValues.length);
    const labels = labelsFor(pointCount, timestampValues);
    const existing = Chart.getChart(canvas);

    // Reuse the canvas instance so one-second updates do not leak Chart objects.
    if (existing) {
      existing.data.labels = labels;
      existing.data.datasets[0].data = cpuValues;
      existing.data.datasets[1].data = ramValues;
      existing.update("none");
      return;
    }

    new Chart(canvas, {
      type: "line",
      data: {
        labels,
        datasets: [
          {
            label: "CPU",
            data: cpuValues,
            borderColor: pinkLine,
            backgroundColor: "rgba(255, 175, 243, 0.22)",
            pointBackgroundColor: pink,
            pointHoverBackgroundColor: pink,
            fill: true,
          },
          {
            label: "RAM",
            data: ramValues,
            borderColor: cyanLine,
            backgroundColor: "rgba(166, 240, 252, 0.18)",
            pointBackgroundColor: cyan,
            pointHoverBackgroundColor: cyan,
            fill: true,
          },
        ],
      },
      options: {
        responsive: true,
        maintainAspectRatio: false,
        animation: false,
        layout: {
          padding: {
            top: 4,
            right: 10,
            bottom: 2,
            left: 4,
          },
        },
        font: {
          family: '"Trebuchet MS", "Avenir Next", Avenir, sans-serif',
          weight: "600",
        },
        interaction: {
          intersect: false,
          mode: "index",
        },
        elements: {
          line: {
            borderWidth: 3,
            tension: 0.28,
          },
          point: {
            borderColor: ink,
            borderWidth: 1,
            hoverRadius: 6,
            radius: pointCount < 20 ? 3 : 0,
          },
        },
        plugins: {
          legend: {
            align: "end",
            labels: {
              color: ink,
              font: {
                family: '"SFMono-Regular", Consolas, "Liberation Mono", monospace',
                weight: "bold",
              },
              boxHeight: 10,
              boxWidth: 10,
              padding: 18,
              pointStyle: "circle",
              usePointStyle: true,
            },
          },
          tooltip: {
            backgroundColor: ink,
            borderColor: ink,
            borderWidth: 1,
            cornerRadius: 10,
            padding: 12,
            titleFont: { weight: "bold" },
            displayColors: true,
            callbacks: {
              label(context) {
                return `${context.dataset.label}: ${percentFormatter.format(context.parsed.y / 100)}`;
              },
            },
          },
        },
        scales: {
          x: {
            grid: { display: false },
            border: { color: axis, width: 1 },
            ticks: {
              color: ink,
              padding: 8,
              font: {
                family: '"SFMono-Regular", Consolas, "Liberation Mono", monospace',
                size: 11,
              },
              // maxTicksLimit: 8,
            },
          },
          y: {
            beginAtZero: true,
            max: 100,
            border: { color: axis, width: 1 },
            grid: {
              color: "rgba(47, 41, 51, 0.12)",
              borderDash: [4, 4],
            },
            ticks: {
              color: ink,
              padding: 8,
              font: {
                family: '"SFMono-Regular", Consolas, "Liberation Mono", monospace',
                size: 11,
              },
              callback(value) {
                return `${value}%`;
              },
            },
          },
        },
      },
    });
  });
}
