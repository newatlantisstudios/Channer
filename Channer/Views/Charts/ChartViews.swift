import UIKit

// MARK: - Chart Data Types

/// Data point for bar and line charts
struct ChartDataPoint {
    let label: String
    let value: Double
    var color: UIColor?

    init(label: String, value: Double, color: UIColor? = nil) {
        self.label = label
        self.value = value
        self.color = color
    }
}

/// Data point for pie charts
struct PieChartDataPoint {
    let label: String
    let value: Double
    let color: UIColor

    var percentage: Double = 0

    init(label: String, value: Double, color: UIColor) {
        self.label = label
        self.value = value
        self.color = color
    }
}

// MARK: - Bar Chart View

/// A custom bar chart view drawn using Core Graphics
class BarChartView: UIView {

    // MARK: - Properties
    var dataPoints: [ChartDataPoint] = [] {
        didSet {
            setNeedsDisplay()
        }
    }

    var barColor: UIColor = .systemBlue
    var labelColor: UIColor = ThemeManager.shared.primaryTextColor
    var gridColor: UIColor = ThemeManager.shared.secondaryTextColor.withAlphaComponent(0.3)
    var showLabels: Bool = true
    var showValues: Bool = true
    var animationDuration: TimeInterval = 0.5
    var cornerRadius: CGFloat = 4
    var barSpacing: CGFloat = 8

    private var animatedProgress: CGFloat = 0
    private var displayLink: CADisplayLink?
    private var animationStartTime: CFTimeInterval = 0

    // MARK: - Initialization
    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }

    private func setup() {
        backgroundColor = .clear
        isOpaque = false
    }

    // MARK: - Animation
    func animateChart() {
        animatedProgress = 0
        animationStartTime = CACurrentMediaTime()

        displayLink?.invalidate()
        displayLink = CADisplayLink(target: self, selector: #selector(updateAnimation))
        displayLink?.add(to: .main, forMode: .common)
    }

    @objc private func updateAnimation() {
        let elapsed = CACurrentMediaTime() - animationStartTime
        let progress = min(1.0, elapsed / animationDuration)

        // Ease-out animation curve
        animatedProgress = CGFloat(1 - pow(1 - progress, 3))

        setNeedsDisplay()

        if progress >= 1.0 {
            displayLink?.invalidate()
            displayLink = nil
        }
    }

    // MARK: - Drawing
    override func draw(_ rect: CGRect) {
        guard !dataPoints.isEmpty else { return }

        let context = UIGraphicsGetCurrentContext()
        context?.saveGState()

        let maxValue = dataPoints.map { $0.value }.max() ?? 1
        let labelHeight: CGFloat = showLabels ? 30 : 0
        let valueHeight: CGFloat = showValues ? 20 : 0
        let chartHeight = rect.height - labelHeight - valueHeight - 10
        let chartWidth = rect.width
        let barWidth = (chartWidth - CGFloat(dataPoints.count + 1) * barSpacing) / CGFloat(dataPoints.count)

        // Draw grid lines
        let gridLineCount = 4
        for i in 0...gridLineCount {
            let y = valueHeight + (chartHeight / CGFloat(gridLineCount)) * CGFloat(i)
            let path = UIBezierPath()
            path.move(to: CGPoint(x: 0, y: y))
            path.addLine(to: CGPoint(x: chartWidth, y: y))
            gridColor.setStroke()
            path.lineWidth = 0.5
            path.stroke()
        }

        // Draw bars
        for (index, dataPoint) in dataPoints.enumerated() {
            let x = barSpacing + CGFloat(index) * (barWidth + barSpacing)
            let barHeight = chartHeight * CGFloat(dataPoint.value / maxValue) * animatedProgress
            let y = valueHeight + chartHeight - barHeight

            let barRect = CGRect(x: x, y: y, width: barWidth, height: barHeight)
            let barPath = UIBezierPath(roundedRect: barRect, byRoundingCorners: [.topLeft, .topRight], cornerRadii: CGSize(width: cornerRadius, height: cornerRadius))

            let color = dataPoint.color ?? barColor
            color.setFill()
            barPath.fill()

            // Draw value label
            if showValues && animatedProgress > 0.5 {
                let valueText = formatValue(dataPoint.value)
                let valueAttributes: [NSAttributedString.Key: Any] = [
                    .font: UIFont.systemFont(ofSize: 10, weight: .medium),
                    .foregroundColor: labelColor
                ]
                let valueSize = valueText.size(withAttributes: valueAttributes)
                let valueRect = CGRect(
                    x: x + (barWidth - valueSize.width) / 2,
                    y: y - valueSize.height - 4,
                    width: valueSize.width,
                    height: valueSize.height
                )
                valueText.draw(in: valueRect, withAttributes: valueAttributes)
            }

            // Draw label
            if showLabels {
                let labelAttributes: [NSAttributedString.Key: Any] = [
                    .font: UIFont.systemFont(ofSize: 10, weight: .regular),
                    .foregroundColor: labelColor
                ]
                let labelSize = dataPoint.label.size(withAttributes: labelAttributes)
                let labelRect = CGRect(
                    x: x + (barWidth - labelSize.width) / 2,
                    y: rect.height - labelHeight + 5,
                    width: labelSize.width,
                    height: labelSize.height
                )
                dataPoint.label.draw(in: labelRect, withAttributes: labelAttributes)
            }
        }

        context?.restoreGState()
    }

    private func formatValue(_ value: Double) -> String {
        if value >= 1000 {
            return String(format: "%.1fK", value / 1000)
        } else if value == floor(value) {
            return String(format: "%.0f", value)
        } else {
            return String(format: "%.1f", value)
        }
    }

    // MARK: - Theme Support
    func updateColors() {
        labelColor = ThemeManager.shared.primaryTextColor
        gridColor = ThemeManager.shared.secondaryTextColor.withAlphaComponent(0.3)
        setNeedsDisplay()
    }
}

// MARK: - Line Chart View

/// A custom line chart view drawn using Core Graphics
class LineChartView: UIView {

    // MARK: - Properties
    var dataPoints: [ChartDataPoint] = [] {
        didSet {
            setNeedsDisplay()
        }
    }

    var lineColor: UIColor = .systemBlue
    var fillColor: UIColor? = nil
    var labelColor: UIColor = ThemeManager.shared.primaryTextColor
    var gridColor: UIColor = ThemeManager.shared.secondaryTextColor.withAlphaComponent(0.3)
    var showLabels: Bool = true
    var showDots: Bool = true
    var showArea: Bool = true
    var lineWidth: CGFloat = 2
    var dotRadius: CGFloat = 4
    var animationDuration: TimeInterval = 0.8

    private var animatedProgress: CGFloat = 0
    private var displayLink: CADisplayLink?
    private var animationStartTime: CFTimeInterval = 0

    // MARK: - Initialization
    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }

    private func setup() {
        backgroundColor = .clear
        isOpaque = false
    }

    // MARK: - Animation
    func animateChart() {
        animatedProgress = 0
        animationStartTime = CACurrentMediaTime()

        displayLink?.invalidate()
        displayLink = CADisplayLink(target: self, selector: #selector(updateAnimation))
        displayLink?.add(to: .main, forMode: .common)
    }

    @objc private func updateAnimation() {
        let elapsed = CACurrentMediaTime() - animationStartTime
        let progress = min(1.0, elapsed / animationDuration)

        // Ease-out animation curve
        animatedProgress = CGFloat(1 - pow(1 - progress, 3))

        setNeedsDisplay()

        if progress >= 1.0 {
            displayLink?.invalidate()
            displayLink = nil
        }
    }

    // MARK: - Drawing
    override func draw(_ rect: CGRect) {
        guard dataPoints.count >= 2 else { return }

        let context = UIGraphicsGetCurrentContext()
        context?.saveGState()

        let maxValue = dataPoints.map { $0.value }.max() ?? 1
        let minValue = max(0, (dataPoints.map { $0.value }.min() ?? 0) * 0.9)
        let valueRange = maxValue - minValue

        let labelHeight: CGFloat = showLabels ? 30 : 0
        let topPadding: CGFloat = 20
        let chartHeight = rect.height - labelHeight - topPadding
        let chartWidth = rect.width
        let pointSpacing = chartWidth / CGFloat(dataPoints.count - 1)

        // Draw grid lines
        let gridLineCount = 4
        for i in 0...gridLineCount {
            let y = topPadding + (chartHeight / CGFloat(gridLineCount)) * CGFloat(i)
            let path = UIBezierPath()
            path.move(to: CGPoint(x: 0, y: y))
            path.addLine(to: CGPoint(x: chartWidth, y: y))
            gridColor.setStroke()
            path.lineWidth = 0.5
            path.stroke()
        }

        // Calculate points
        var points: [CGPoint] = []
        for (index, dataPoint) in dataPoints.enumerated() {
            let x = CGFloat(index) * pointSpacing
            let normalizedValue = (dataPoint.value - minValue) / valueRange
            let y = topPadding + chartHeight - (chartHeight * CGFloat(normalizedValue) * animatedProgress)
            points.append(CGPoint(x: x, y: y))
        }

        // Draw area fill
        if showArea, let fillColor = fillColor ?? lineColor.withAlphaComponent(0.2) as UIColor? {
            let areaPath = UIBezierPath()
            areaPath.move(to: CGPoint(x: 0, y: topPadding + chartHeight))

            for point in points {
                areaPath.addLine(to: point)
            }

            areaPath.addLine(to: CGPoint(x: chartWidth, y: topPadding + chartHeight))
            areaPath.close()

            fillColor.setFill()
            areaPath.fill()
        }

        // Draw line
        let linePath = UIBezierPath()
        linePath.move(to: points[0])

        for i in 1..<points.count {
            // Smooth curve using quadratic bezier
            let midPoint = CGPoint(
                x: (points[i-1].x + points[i].x) / 2,
                y: (points[i-1].y + points[i].y) / 2
            )
            linePath.addQuadCurve(to: midPoint, controlPoint: points[i-1])
            linePath.addQuadCurve(to: points[i], controlPoint: midPoint)
        }

        lineColor.setStroke()
        linePath.lineWidth = lineWidth
        linePath.lineCapStyle = .round
        linePath.lineJoinStyle = .round
        linePath.stroke()

        // Draw dots
        if showDots && animatedProgress > 0.5 {
            for point in points {
                let dotPath = UIBezierPath(arcCenter: point, radius: dotRadius, startAngle: 0, endAngle: .pi * 2, clockwise: true)
                lineColor.setFill()
                dotPath.fill()

                // White inner dot
                let innerDotPath = UIBezierPath(arcCenter: point, radius: dotRadius - 2, startAngle: 0, endAngle: .pi * 2, clockwise: true)
                UIColor.white.setFill()
                innerDotPath.fill()
            }
        }

        // Draw labels
        if showLabels {
            for (index, dataPoint) in dataPoints.enumerated() {
                let x = CGFloat(index) * pointSpacing
                let labelAttributes: [NSAttributedString.Key: Any] = [
                    .font: UIFont.systemFont(ofSize: 9, weight: .regular),
                    .foregroundColor: labelColor
                ]
                let labelSize = dataPoint.label.size(withAttributes: labelAttributes)
                let labelRect = CGRect(
                    x: x - labelSize.width / 2,
                    y: rect.height - labelHeight + 5,
                    width: labelSize.width,
                    height: labelSize.height
                )
                dataPoint.label.draw(in: labelRect, withAttributes: labelAttributes)
            }
        }

        context?.restoreGState()
    }

    // MARK: - Theme Support
    func updateColors() {
        labelColor = ThemeManager.shared.primaryTextColor
        gridColor = ThemeManager.shared.secondaryTextColor.withAlphaComponent(0.3)
        setNeedsDisplay()
    }
}

// MARK: - Pie Chart View

/// A custom pie chart view drawn using Core Graphics
class PieChartView: UIView {

    // MARK: - Properties
    var dataPoints: [PieChartDataPoint] = [] {
        didSet {
            calculatePercentages()
            setNeedsDisplay()
        }
    }

    var labelColor: UIColor = ThemeManager.shared.primaryTextColor
    var showLabels: Bool = true
    var showPercentages: Bool = true
    var innerRadiusRatio: CGFloat = 0.5 // For donut chart, 0 for pie
    var animationDuration: TimeInterval = 0.8

    private var animatedProgress: CGFloat = 0
    private var displayLink: CADisplayLink?
    private var animationStartTime: CFTimeInterval = 0
    private var processedDataPoints: [PieChartDataPoint] = []

    // MARK: - Initialization
    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }

    private func setup() {
        backgroundColor = .clear
        isOpaque = false
    }

    private func calculatePercentages() {
        let total = dataPoints.reduce(0) { $0 + $1.value }
        guard total > 0 else {
            processedDataPoints = []
            return
        }

        processedDataPoints = dataPoints.map { point in
            var newPoint = point
            newPoint.percentage = point.value / total * 100
            return newPoint
        }
    }

    // MARK: - Animation
    func animateChart() {
        animatedProgress = 0
        animationStartTime = CACurrentMediaTime()

        displayLink?.invalidate()
        displayLink = CADisplayLink(target: self, selector: #selector(updateAnimation))
        displayLink?.add(to: .main, forMode: .common)
    }

    @objc private func updateAnimation() {
        let elapsed = CACurrentMediaTime() - animationStartTime
        let progress = min(1.0, elapsed / animationDuration)

        // Ease-out animation curve
        animatedProgress = CGFloat(1 - pow(1 - progress, 3))

        setNeedsDisplay()

        if progress >= 1.0 {
            displayLink?.invalidate()
            displayLink = nil
        }
    }

    // MARK: - Drawing
    override func draw(_ rect: CGRect) {
        guard !processedDataPoints.isEmpty else { return }

        let context = UIGraphicsGetCurrentContext()
        context?.saveGState()

        let center = CGPoint(x: rect.midX, y: rect.midY)
        let radius = min(rect.width, rect.height) / 2 - 20
        let innerRadius = radius * innerRadiusRatio

        var startAngle: CGFloat = -.pi / 2 // Start from top
        let total = processedDataPoints.reduce(0) { $0 + $1.value }

        for dataPoint in processedDataPoints {
            let endAngle = startAngle + CGFloat(dataPoint.value / total) * 2 * .pi * animatedProgress

            // Draw slice
            let path = UIBezierPath()
            path.move(to: CGPoint(
                x: center.x + innerRadius * cos(startAngle),
                y: center.y + innerRadius * sin(startAngle)
            ))
            path.addArc(withCenter: center, radius: radius, startAngle: startAngle, endAngle: endAngle, clockwise: true)
            path.addArc(withCenter: center, radius: innerRadius, startAngle: endAngle, endAngle: startAngle, clockwise: false)
            path.close()

            dataPoint.color.setFill()
            path.fill()

            // Draw label at midpoint
            if showLabels && animatedProgress > 0.7 {
                let midAngle = (startAngle + endAngle) / 2
                let labelRadius = radius * 0.75

                let labelCenter = CGPoint(
                    x: center.x + labelRadius * cos(midAngle),
                    y: center.y + labelRadius * sin(midAngle)
                )

                let labelText = showPercentages ? String(format: "%.0f%%", dataPoint.percentage) : dataPoint.label
                let labelAttributes: [NSAttributedString.Key: Any] = [
                    .font: UIFont.systemFont(ofSize: 11, weight: .semibold),
                    .foregroundColor: UIColor.white
                ]
                let labelSize = labelText.size(withAttributes: labelAttributes)
                let labelRect = CGRect(
                    x: labelCenter.x - labelSize.width / 2,
                    y: labelCenter.y - labelSize.height / 2,
                    width: labelSize.width,
                    height: labelSize.height
                )
                labelText.draw(in: labelRect, withAttributes: labelAttributes)
            }

            startAngle = endAngle
        }

        context?.restoreGState()
    }

    // MARK: - Theme Support
    func updateColors() {
        labelColor = ThemeManager.shared.primaryTextColor
        setNeedsDisplay()
    }
}

// MARK: - Chart Legend View

/// A view displaying the legend for charts
class ChartLegendView: UIView {

    // MARK: - Properties
    var items: [(String, UIColor)] = [] {
        didSet {
            setupItems()
        }
    }

    private let stackView = UIStackView()

    // MARK: - Initialization
    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }

    private func setup() {
        stackView.axis = .vertical
        stackView.spacing = 8
        stackView.alignment = .leading
        stackView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stackView)

        NSLayoutConstraint.activate([
            stackView.topAnchor.constraint(equalTo: topAnchor),
            stackView.leadingAnchor.constraint(equalTo: leadingAnchor),
            stackView.trailingAnchor.constraint(equalTo: trailingAnchor),
            stackView.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])
    }

    private func setupItems() {
        stackView.arrangedSubviews.forEach { $0.removeFromSuperview() }

        for (label, color) in items {
            let itemView = createLegendItem(label: label, color: color)
            stackView.addArrangedSubview(itemView)
        }
    }

    private func createLegendItem(label: String, color: UIColor) -> UIView {
        let container = UIView()

        let colorDot = UIView()
        colorDot.backgroundColor = color
        colorDot.layer.cornerRadius = 6
        colorDot.translatesAutoresizingMaskIntoConstraints = false

        let labelView = UILabel()
        labelView.text = label
        labelView.font = UIFont.systemFont(ofSize: 12, weight: .regular)
        labelView.textColor = ThemeManager.shared.primaryTextColor
        labelView.translatesAutoresizingMaskIntoConstraints = false

        container.addSubview(colorDot)
        container.addSubview(labelView)

        NSLayoutConstraint.activate([
            colorDot.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            colorDot.centerYAnchor.constraint(equalTo: container.centerYAnchor),
            colorDot.widthAnchor.constraint(equalToConstant: 12),
            colorDot.heightAnchor.constraint(equalToConstant: 12),

            labelView.leadingAnchor.constraint(equalTo: colorDot.trailingAnchor, constant: 8),
            labelView.centerYAnchor.constraint(equalTo: container.centerYAnchor),
            labelView.trailingAnchor.constraint(equalTo: container.trailingAnchor),

            container.heightAnchor.constraint(equalToConstant: 24)
        ])

        return container
    }

    func updateColors() {
        for container in stackView.arrangedSubviews {
            for subview in container.subviews {
                if let label = subview as? UILabel {
                    label.textColor = ThemeManager.shared.primaryTextColor
                }
            }
        }
    }
}
