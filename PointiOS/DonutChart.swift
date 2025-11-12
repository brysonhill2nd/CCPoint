//
//  DonutChart.swift
//  PointiOS
//
//  Modern donut chart component for visualizing data distribution
//

import SwiftUI

// MARK: - Donut Chart Data Model
struct DonutChartData: Identifiable {
    let id = UUID()
    let label: String
    let value: Double
    let color: Color
    let icon: String?

    init(label: String, value: Double, color: Color, icon: String? = nil) {
        self.label = label
        self.value = value
        self.color = color
        self.icon = icon
    }
}

// MARK: - Donut Chart View
struct DonutChart: View {
    let data: [DonutChartData]
    let centerText: String?
    let size: CGFloat
    let lineWidth: CGFloat
    @State private var animationProgress: CGFloat = 0

    init(data: [DonutChartData], centerText: String? = nil, size: CGFloat = 180, lineWidth: CGFloat = 35) {
        self.data = data
        self.centerText = centerText
        self.size = size
        self.lineWidth = lineWidth
    }

    private var total: Double {
        data.reduce(0) { $0 + $1.value }
    }

    private var slices: [(data: DonutChartData, startAngle: Angle, endAngle: Angle)] {
        var currentAngle = Angle(degrees: -90)
        var slices: [(DonutChartData, Angle, Angle)] = []

        for item in data {
            let percentage = item.value / total
            let sliceAngle = Angle(degrees: 360 * percentage)
            let endAngle = currentAngle + sliceAngle
            slices.append((item, currentAngle, endAngle))
            currentAngle = endAngle
        }

        return slices
    }

    var body: some View {
        VStack(spacing: 24) {
            // Donut Chart
            ZStack {
                // Background circle
                Circle()
                    .stroke(Color(.systemGray6), lineWidth: lineWidth)
                    .frame(width: size, height: size)

                // Chart slices
                ForEach(Array(slices.enumerated()), id: \.offset) { index, slice in
                    DonutSlice(
                        startAngle: slice.startAngle,
                        endAngle: slice.endAngle,
                        color: slice.data.color,
                        lineWidth: lineWidth
                    )
                    .frame(width: size, height: size)
                    .rotationEffect(.degrees(360 * Double(animationProgress)))
                    .animation(.easeInOut(duration: 1.0).delay(Double(index) * 0.1), value: animationProgress)
                }

                // Center text
                if let centerText = centerText {
                    Text(centerText)
                        .font(.system(size: 32, weight: .bold))
                        .foregroundColor(.primary)
                }
            }

            // Legend
            VStack(alignment: .leading, spacing: 12) {
                ForEach(data) { item in
                    HStack(spacing: 12) {
                        // Color indicator
                        RoundedRectangle(cornerRadius: 4)
                            .fill(item.color)
                            .frame(width: 20, height: 20)

                        // Icon (if provided)
                        if let icon = item.icon {
                            Text(icon)
                                .font(.system(size: 16))
                        }

                        // Label
                        Text(item.label)
                            .font(.system(size: 15, weight: .medium))
                            .foregroundColor(.primary)

                        Spacer()

                        // Value and percentage
                        VStack(alignment: .trailing, spacing: 2) {
                            Text("\(Int(item.value)) games")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(.primary)

                            Text("\(Int((item.value / total) * 100))%")
                                .font(.system(size: 12))
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 1.0)) {
                animationProgress = 1.0
            }
        }
    }
}

// MARK: - Donut Slice Shape
struct DonutSlice: View {
    let startAngle: Angle
    let endAngle: Angle
    let color: Color
    let lineWidth: CGFloat

    var body: some View {
        Circle()
            .trim(from: startAngle.radians / (2 * .pi), to: endAngle.radians / (2 * .pi))
            .stroke(color, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
            .rotationEffect(.degrees(-90))
    }
}

// MARK: - Preview
struct DonutChart_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 40) {
            // Sport Distribution Example
            DonutChart(
                data: [
                    DonutChartData(label: "Pickleball", value: 15, color: .green, icon: "🥒"),
                    DonutChartData(label: "Tennis", value: 8, color: .yellow, icon: "🎾"),
                    DonutChartData(label: "Padel", value: 3, color: .orange, icon: "🏓")
                ],
                centerText: "26"
            )

            // Game Type Example
            DonutChart(
                data: [
                    DonutChartData(label: "Singles", value: 8, color: .blue),
                    DonutChartData(label: "Doubles", value: 12, color: .purple)
                ],
                centerText: "20"
            )
        }
        .padding()
        .background(Color(.systemBackground))
    }
}
