import UIKit

/// A type that represents an image.
public protocol ImageProtocol {
	/// Size of the image.
	var size: CGSize { get }
}

// MARK: -

/// A type that represents a 2D container.
public protocol ContainerProtocol {
	/// Size of the container.
	var size: CGSize { get }
}

// MARK: -

/// A kind of layout which places images in a 2D container while keeping that
/// each side of each images is aligned to either one side of another image or
/// one side of the container.
///
/// Images may probably be scaled in such a layout.
public struct AlignedImageLayout {
	/// The regions for the given images in the same order.
	///
	/// Zero point is at left-top of the container.
	public let regions: [CGRect]
	
	/// The score of container coverage, which is in the range of [0, 1].
	///
	/// Less white space leads to higher score.
	public let scoreOfCoverage: CGFloat
	
	/// The score of scale accordance of images, which is in the range of [0, 1].
	///
	/// Closer image scales lead to higher score.
	public let scoreOfScaleAccordance: CGFloat
	
	/// The score of area accordance of images, which is in the range of [0, 1].
	///
	/// Closer image areas lead to higher score.
	public let scoreOfAreaAccordance: CGFloat
	
	/// The overall score, which is in the range of [0, 1]
	public let score: CGFloat
	
	internal init(
		regions: [CGRect],
		scoreOfCoverage: CGFloat,
		scoreOfScaleAccordance: CGFloat,
		scoreOfAreaAccordance: CGFloat
	) {
		assert(0.0 ... 1.0 ~= scoreOfCoverage)
		assert(0.0 ... 1.0 ~= scoreOfScaleAccordance)
		assert(0.0 ... 1.0 ~= scoreOfAreaAccordance)
		
		self.regions = regions
		self.scoreOfCoverage = scoreOfCoverage
		self.scoreOfScaleAccordance = scoreOfScaleAccordance
		self.scoreOfAreaAccordance = scoreOfAreaAccordance
		
		score = scoreOfCoverage * scoreOfScaleAccordance * scoreOfAreaAccordance
		assert(0.0 ... 1.0 ~= score)
	}
}

// MARK: -

/// A generator of `AlignedImageLayout`.
public struct AlignedImageLayoutGenerator {
	/// The horizontal and vertical space between adjacent images.
	public let spacing: (horizontal: CGFloat, vertical: CGFloat)
	
	/// The max level of group orientation alternation.
	public let splitLevelLimit: Int?
	
	/// Returns all possible layouts for specific images in a specific container.
	/// 
	/// A limit of the number of results can be specfied. If so, layouts with
	/// lower score may be cut off.
	///
	/// - parameters:
	/// 	- images:
	/// 		The images to place.
	/// 	- container:
	/// 		The container to place in.
	/// 	- resultCountLimit:
	/// 		How many results should be kept, or `nil` for unlimited.
	public func generateLayouts(
		for images: [ImageProtocol],
		in container: ContainerProtocol,
		upTo resultCountLimit: Int? = nil
	) -> [AlignedImageLayout] {
		let worker = Worker(
			spacing: spacing, 
			splitLevelLimit: splitLevelLimit, 
			images: images, 
			container: container, 
			resultCountLimit: resultCountLimit
		)
		let layouts = worker.work()
		return layouts
	}
	
}

// MARK: -

fileprivate struct Worker {
	fileprivate let spacing: (horizontal: CGFloat, vertical: CGFloat)
	
	fileprivate let splitLevelLimit: Int?
	
	fileprivate let imageCount: Int
	
	fileprivate let imageSizes: [CGSize]
	
	fileprivate let imageAspectRatios: [CGFloat]
	
	fileprivate let imageInversedAspectRatios: [CGFloat]
	
	fileprivate let containerSize: CGSize
	
	fileprivate let resultCountLimit: Int?
	
	fileprivate init(
		spacing: (horizontal: CGFloat, vertical: CGFloat),
		splitLevelLimit: Int?,
		images: [ImageProtocol],
		container: ContainerProtocol,
		resultCountLimit: Int?
	) {
		self.spacing = spacing
		self.splitLevelLimit = splitLevelLimit
		self.resultCountLimit = resultCountLimit
		
		imageCount = images.count
		imageSizes = images.map { $0.size }
		imageAspectRatios = imageSizes.map { $0.aspectRatio }
		imageInversedAspectRatios = imageSizes.map { $0.inversedAspectRatio }
		
		containerSize = container.size
	}
	
	fileprivate func work() -> [AlignedImageLayout] {
		// 结果数量限制为0的情况下，不需要深入计算。
		guard resultCountLimit != 0 else {
			return []
		}
		
		/// 对于当前的数量和拆分等级，所有的组合情况。
		let combos = evolvedCombos(length: imageCount, splitLevelLimit: splitLevelLimit)
		
		/// 创建布局组合的数组，其中包含横向和纵向两种情况。
		let layoutCombos = combos.reduce([]) {
			(layoutCombos, combo) -> [LayoutComboProtocol] in
			
			var layoutCombos = layoutCombos
			layoutCombos.append(makeLayoutCombo(combo: combo, isVertical: false))
			layoutCombos.append(makeLayoutCombo(combo: combo, isVertical: true))
			
			return layoutCombos
		}
		
		// 计算布局的数组。
		// 根据结果数量限制的不同情况，进行不同的优化。
		if let resultCountLimit = resultCountLimit {
			/// 由高分布局组成的数组，按照分数降序排列。长度不超过resultCount。
			var layouts: [AlignedImageLayout] = []
			
			// 生成布局，并尝试加入布局数组。
			for layoutCombo in layoutCombos {
				guard let layout = makeLayout(layoutCombo: layoutCombo) else {
					continue
				}
				
				// 找出可插入位置，从此之后的布局分数均低于当前布局。
				if let index = layouts.firstIndex(where: { layout.score > $0.score }) {
					layouts.insert(layout, at: index)
					
					if layouts.count > resultCountLimit {
						layouts.removeLast()
					}
				}
				// 无法插入，尝试将当前布局放置于数组尾部。
				else {
					if layouts.count < resultCountLimit {
						layouts.append(layout)
					}
				}
			}
			
			return layouts
		}
		else {
			/// 由所有布局组成的数组。
			var layouts: [AlignedImageLayout] = []
			
			// 生成所有的布局。
			for layoutCombo in layoutCombos {
				guard let layout = makeLayout(layoutCombo: layoutCombo) else {
					continue
				}
				
				layouts.append(layout)
			}
			
			// 按分数降序排列。
			layouts.sort { $0.score >= $1.score }
			
			return layouts
		}
	}
	
	private func makeLayoutCombo(fromIndex: Int = 0, combo: ComboProtocol, isVertical: Bool) -> LayoutComboProtocol {
		let isHorizontal = !isVertical
		
		if let combo = combo as? SimpleCombo {
			let parameters: LayoutParameters = {
				let n = combo.length
				
				// 如果是横向排列，有：
				// A = (A0 + A1 + ... + An)
				// B = Sh * (n - 1)
				if isHorizontal {
					let a = (
						(fromIndex ..< fromIndex + n).reduce(0) {
							return $0 + imageAspectRatios[$1]
						}
					)
					let b = spacing.horizontal * CGFloat(n - 1)
					
					return LayoutParameters(a: a, b: b)
				}
				// 如果是纵向排列，有：
				// C = (C0 + C1 + ... + Cn)
				// D = Sv * (n - 1)
				else {
					let c = (
						(fromIndex ..< fromIndex + n).reduce(0) {
							return $0 + imageInversedAspectRatios[$1]
						}
					)
					let d = spacing.vertical * CGFloat(n - 1)
					
					return LayoutParameters(c: c, d: d)
				
				}
			} ()
			
			let layoutCombo = SimpleLayoutCombo(length: combo.length, isVertical: isVertical, parameters: parameters)
			
			return layoutCombo
		}
		
		if let combo = combo as? ComplexCombo {
			let childCombos = combo.children
			
			let childLayoutCombos: [LayoutComboProtocol] = {
				var index = fromIndex
				
				return childCombos.map {
					let childLayoutCombo = makeLayoutCombo(fromIndex: index, combo: $0, isVertical: isHorizontal)
					index += $0.length
					
					return childLayoutCombo
				}
			} ()
			
			let parameters: LayoutParameters = {
				let n = childCombos.count
				
				// 如果是横向排列，有：
				// A = (A0 + A1 + ... + An)
				// B = (B0 + B1 + ... + Bn) + Sh * (n - 1)
				if isHorizontal {
					let (a, b) = childLayoutCombos.reduce(
						(
							a: CGFloat(0),
							b: spacing.horizontal * CGFloat(n - 1)
						)
					) {
						return (
							$0.a + $1.parameters.a,
							$0.b + $1.parameters.b
						)
					}
					
					return LayoutParameters(a: a, b: b)
				}
				// 如果是纵向排列，有：
				// C = (C0 + C1 + ... + Cn)
				// D = (D0 + D1 + ... + Dn) + Sv * (n - 1)
				else {
					let (c, d) = childLayoutCombos.reduce(
						(
							c: CGFloat(0),
							d: spacing.vertical * CGFloat(n - 1)
						)
					) {
						return (
							$0.c + $1.parameters.c,
							$0.d + $1.parameters.d
						)
					}
					
					return LayoutParameters(c: c, d: d)
				}
			} ()
			
			let layoutCombo = ComplexLayoutCombo(children: childLayoutCombos, isVertical: isVertical, parameters: parameters)
			
			return layoutCombo
		}
		
		fatalError()
	}
	
	/// 将布局组合转化为布局。
	///
	/// - warning:
	/// 	由于间隙的存在，可能存在计算得出一个区域的尺寸为负值的情况，这种情况下整个布局不成立。
	///
	/// - parameters:
	/// 	- layoutCombo: 布局组合。
	///
	/// - returns: 转化而成的布局，或`nil`。
	private func makeLayout(layoutCombo: LayoutComboProtocol) -> AlignedImageLayout? {
		let baseRegion: CGRect = {
			let parameters = layoutCombo.parameters
			
			let size: CGSize = {
				if true {
					let height = containerSize.height
					let width = height * parameters.a + parameters.b
					
					if width <= containerSize.width {
						return CGSize(width: width, height: height)
					}
				}
				
				if true {
					let width = containerSize.width
					let height = width * parameters.c + parameters.d
					
					if height <= containerSize.height {
						return CGSize(width: width, height: height)
					}
				}
				
				fatalError()
			} ()
			
			let origin = CGPoint(x: (containerSize.width - size.width) / 2, y: (containerSize.height - size.height) / 2)
			
			return CGRect(origin: origin, size: size)
		} ()
		
		guard let regions = makeRegions(baseRegion: baseRegion, layoutCombo: layoutCombo) else {
			return nil
		}
		
		/// 面积覆盖率。范围为(0, 1)，量纲为(长度/长度)^2。
		let coverage = baseRegion.size.area / containerSize.area

		/// 由每个图片的缩放比例组成的数组。每一项范围为(0, +Inf)，量纲为（长度/长度）。
		let scales: [CGFloat] = zip(imageSizes, regions).map { $0.0.width / $0.1.size.width }
		/// 由每个图片的缩放比例的对数组成的数组。每一项范围为(-Inf, +Inf)，量纲为log(长度/长度)。
		let logScales = scales.map { log($0) }
		/// 每个图片的缩放比例的对数的平均值。范围为(-Inf, +Inf)，量纲为log(长度/长度)。
		let averageLogScale = logScales.reduce(0, +) / CGFloat(logScales.count)
		/// 每个图片的缩放比例的对数的标准差。范围为[0, +Inf)，量纲为1。
		let standardDeviationForLogScales = sqrt(logScales.reduce(0) { $0 + pow($1 - averageLogScale, 2) }) / CGFloat(logScales.count)
		
		/// 由每个区域的面积组成的数组。每一项范围为(0, +Inf)，量纲为长度^2。
		let areas: [CGFloat] = regions.map { $0.size.area }
		/// 由每个区域的面积的对数组成的数组。每一项范围为(-Inf, +Inf)，量纲为log(长度^2)。
		let logAreas = areas.map { log($0) }
		/// 每个区域的面积的对数的平均值。范围为(-Inf, +Inf)，量纲为log(长度^2)。
		let averageLogAreas = logAreas.reduce(0, +) / CGFloat(logAreas.count)
		/// 每个区域的面积的对数的标准差。范围为[0, +Inf)，量纲为1。
		let standardDeviationForLogAreas = sqrt(logAreas.reduce(0) { $0 + pow($1 - averageLogAreas, 2) }) / CGFloat(logAreas.count)
		
		/// 覆盖率评分。范围为(0, 1]。
		let scoreOfCoverage = pow(coverage, 0.5)
		/// 缩放比例一致性评分。范围为(0, 1]。
		let scoreOfScaleAccordance = pow(2, -standardDeviationForLogScales)
		/// 面积一致性评分。范围为(0, 1)
		let scoreOfAreaAccordance = pow(2, -standardDeviationForLogAreas)
		
		let layout = AlignedImageLayout(
			regions: regions,
			scoreOfCoverage: scoreOfCoverage,
			scoreOfScaleAccordance: scoreOfScaleAccordance,
			scoreOfAreaAccordance: scoreOfAreaAccordance
		)
		
		return layout
	}
	
	/// 生成区域数组。
	///
	/// - warning:
	/// 	由于间隙的存在，可能存在计算得出一个区域的尺寸为负值的情况，这种情况下整个区域数组不成立。
	///
	/// - parameters:
	/// 	- fromIndex: 使用图片的起始序号。
	/// 	- baseRegion: 整个区域。
	/// 	- layoutCombo: 布局组合。
	///
	/// - returns: 指定布局组合内使用到的元素的区域数组，或`nil`。
	private func makeRegions(
		fromIndex: Int = 0, baseRegion: CGRect, layoutCombo: LayoutComboProtocol
	) -> [CGRect]? {
		let isHorizontal = !layoutCombo.isVertical
		
		if let layoutCombo = layoutCombo as? SimpleLayoutCombo {
			if isHorizontal {
				if baseRegion.size.width <= spacing.horizontal * CGFloat(layoutCombo.length - 1) {
					return nil
				}
				
				let height = baseRegion.size.height
				
				var regions: [CGRect] = []
				var origin = baseRegion.origin
				
				for index in fromIndex ..< fromIndex + layoutCombo.length {
					let width = height * imageAspectRatios[index]
					
					let region = CGRect(origin: origin, size: CGSize(width: width, height: height))
					regions.append(region)
					
					origin.x += (width + spacing.horizontal)
				}
				
				return regions
			}
			else {
				if baseRegion.size.height <= spacing.vertical * CGFloat(layoutCombo.length - 1) {
					return nil
				}
				
				let width = baseRegion.size.width
				
				var regions: [CGRect] = []
				var origin = baseRegion.origin
				
				for index in fromIndex ..< fromIndex + layoutCombo.length {
					let height = width * imageInversedAspectRatios[index]
					
					let region = CGRect(origin: origin, size: CGSize(width: width, height: height))
					regions.append(region)
					
					origin.y += (height + spacing.vertical)
				}
				
				return regions
			}
		}
		
		if let layoutCombo = layoutCombo as? ComplexLayoutCombo {
			if isHorizontal {
				if baseRegion.size.width <= spacing.horizontal * CGFloat(layoutCombo.children.count - 1) {
					return nil
				}
				
				let height = baseRegion.size.height
				
				var regions: [CGRect] = []
				var origin = baseRegion.origin
				var index = fromIndex
				
				for child in layoutCombo.children {
					let width = height * child.parameters.a + child.parameters.b
					
					let childBaseRegion = CGRect(origin: origin, size: CGSize(width: width, height: height))
					
					guard let childRegions = makeRegions(fromIndex: index, baseRegion: childBaseRegion, layoutCombo: child) else {
						return nil
					}
					regions.append(contentsOf: childRegions)
					
					origin.x += (width + spacing.horizontal)
					index += child.length
				}
				
				return regions
			}
			else {
				if baseRegion.size.height <= spacing.vertical * CGFloat(layoutCombo.children.count - 1) {
					return nil
				}
				
				let width = baseRegion.size.width
				
				var regions: [CGRect] = []
				var origin = baseRegion.origin
				var index = fromIndex
				
				for child in layoutCombo.children {
					let height = width * child.parameters.c + child.parameters.d
					
					let childBaseRegion = CGRect(origin: origin, size: CGSize(width: width, height: height))
					
					guard let childRegions = makeRegions(fromIndex: index, baseRegion: childBaseRegion, layoutCombo: child) else {
						return nil
					}
					regions.append(contentsOf: childRegions)
					
					origin.y += (height + spacing.vertical)
					index += child.length
				}
				
				return regions
			}
		}
		
		// 不应执行到此处。
		fatalError()
	}
}

// MARK: -

/// 组合协议。
fileprivate protocol ComboProtocol {
	/// 长度，即本组合内包含的元素数量。
	var length: Int { get }
	
	/// 以本组合为基础，获取演化之后得到的所有组合的数组。
	///
	/// - parameters:
	/// 	- splitLevelLimit: 分裂层级上限。为0时表示不可分裂，为`nil`时表示不限制。
	func evolved(splitLevelLimit: Int?) -> [ComboProtocol]
}

// MARK: -

/// 简单组合。
///
/// 简单组合中包含一定数量的元素，并且这些元素处于同一层级。
fileprivate struct SimpleCombo : ComboProtocol {
	fileprivate init(length: Int) {
		self.length = length
	}
	
	// MARK: Conform - ComboProtocol
	
	fileprivate let length: Int
	
	fileprivate func evolved(splitLevelLimit: Int? = nil) -> [ComboProtocol] {
		// 对于n个项来说，有序分组的方式有2^(n-1)种。对于[0, 2^(n-1)-1]间的任意一个数值，
		// 将其看作n-1位的二进制数。其第i位对应第i+1个项，如果这一位为0，则对应的项处于和前
		// 一项同一个分组中，否则新起一组。
		
		var allEvolvedCombos: [ComboProtocol] = [self]
		
		// 如果自身长度只有1或2，那么对其进行分裂是没有意义的。
		// 仅当长度大于2时，才考虑进一步分裂。
		//
		// 另外，同时需要考虑分裂层级的限制。当限制为0时，不作分裂。
		if length > 2 && splitLevelLimit != 0 {
			// 以[0, 2^(n-1)-1]中每一个数值作为种子，进行计算。
			//
			// 其中，0对应不作任何分裂的情况，即自身，已经在数组中；而2^(n-1)-1对应全部打散
			// 的情况，没有实际意义。这两个数值将不作考虑。
			//
			// 实际上，遍历的范围是[1, 2^(n-1)-2]
			for seed in 1 ... (1 << (length - 1) - 2) {
				/// 每一节的长度的数组。
				var sectorLengths: [Int] = []
				
				// 根据之前的规则，对于种子中的每一个比特，如果为0，则增加当前节的长度；如果
				// 为1，则新建一节。
				var sectorLength = 1
				for i in 0 ..< length - 1 {
					if ((seed >> i) & 1) == 0 {
						sectorLength += 1
					}
					else {
						sectorLengths.append(sectorLength)
						sectorLength = 1
					}
				}
				sectorLengths.append(sectorLength)
				
				// 创建一个复杂组合，其中包含这些长度的简单组合。
				let simpleCombos = sectorLengths.map { SimpleCombo(length: $0) }
				let complexCombo = ComplexCombo(children: simpleCombos)
				
				// 对这个复杂组合进行演化，并记录。
				let nextSplitLevelLimit = splitLevelLimit?.minusOne()
				let evolvedCombos = complexCombo.evolved(splitLevelLimit: nextSplitLevelLimit)
				allEvolvedCombos += evolvedCombos
			}
		}
		
		return allEvolvedCombos
	}
}

// MARK: -

/// 复杂组合。
///
/// 复杂组合由多个下级组合组成。
fileprivate struct ComplexCombo : ComboProtocol {
	/// [missing]
	fileprivate let children: [ComboProtocol]
	
	fileprivate init(children: [ComboProtocol]) {
		assert(children.count > 1)
		
		self.children = children
		
		length = children.reduce(0) { $0 + $1.length }
	}
	
	// MARK: Conform - ComboProtocol
	
	fileprivate let length: Int
	
	fileprivate func evolved(splitLevelLimit: Int? = nil) -> [ComboProtocol] {
		var allEvolvedCombos = [self]
		
		if splitLevelLimit != 0 {
			/// 由对于每一个子组合的演化组合数组组成的数组。
			let evolvedCombosByChild = children.map {
				$0.evolved(splitLevelLimit: splitLevelLimit)
			}
			
			/// 为每一个子组合选中一个演化组合的序号，由其组成的数组。
			var selectedEvolvedComboIndexes = Array(repeating: 0, count: children.count)
			/// 为每一个子组合选中一个演化组合，由其组成的数组。
			var selectedEvolvedCombos = evolvedCombosByChild.map { $0[0] }
			
			// 序号数组(0, 0, ..., 0)对应的组合为自身，已经在结果数组中。
			// 跳过(0, 0, ..., 0)，遍历其他所有的组合可能。
			LOOP0:
			while true {
				// 进位，如果越界则跳出循环。
				var position = 0
				while true {
					if position >= children.count {
						break LOOP0
					}
					
					let index = selectedEvolvedComboIndexes[position]
					let indexPlusOne = index + 1
					
					// 在当前位上进位成功，更新当前位上的序号及对应的演化组合。
					if indexPlusOne < evolvedCombosByChild[position].count {
						selectedEvolvedComboIndexes[position] = indexPlusOne
						selectedEvolvedCombos[position] = evolvedCombosByChild[position][indexPlusOne]
						
						break
					}
					// 在当前位上进位不成功，将当前位上的序号及对应的演化组合归0，并进入下一位的进位。
					else {
						if index != 0 {
							selectedEvolvedComboIndexes[position] = 0
							selectedEvolvedCombos[position] = evolvedCombosByChild[position][0]
						}
						
						position += 1
					}
				}
				
				let complexCombo = ComplexCombo(children: selectedEvolvedCombos)
				allEvolvedCombos.append(complexCombo)
			}
		}
		
		return allEvolvedCombos
	}
	
}

// MARK: -

fileprivate struct ComboKey : Hashable {
	let length: Int
	
	let splitLevelLimit: Int?
}

fileprivate var cachedEvolvedCombos: [ComboKey : [ComboProtocol]] = [:]

fileprivate func evolvedCombos(length: Int, splitLevelLimit: Int?) -> [ComboProtocol] {
	let key = ComboKey(length: length, splitLevelLimit: splitLevelLimit)
	
	if let evolvedCombos = cachedEvolvedCombos[key] {
		return evolvedCombos
	}
	
	let evolvedCombos = SimpleCombo(length: length).evolved(splitLevelLimit: splitLevelLimit)
	cachedEvolvedCombos[key] = evolvedCombos
	
	return evolvedCombos
}

// MARK: -

/// 区域的布局参数。
///
/// - note:
/// 	计区域宽度为W，高度为H。有：
/// 	```
/// 	W = A * H + B
/// 	H = C * W + D
/// 	```
/// 	另可以推出：
/// 	```
/// 	A = 1 / C
/// 	B = - (D / C)
/// 	C = 1 / A
/// 	D = - (B / A)
/// 	```
fileprivate struct LayoutParameters {
	fileprivate let a: CGFloat
	fileprivate let b: CGFloat
	fileprivate let c: CGFloat
	fileprivate let d: CGFloat
	
	fileprivate init(a: CGFloat, b: CGFloat) {
		assert(a != 0)
		
		self.a = a
		self.b = b
		
		c = 1 / a
		d = -b / a
	}
	
	fileprivate init(c: CGFloat, d: CGFloat) {
		assert(c != 0)
		
		self.c = c
		self.d = d
		
		a = 1 / c
		b = -d / c
	}
}

// MARK: -

/// 布局组合协议。
fileprivate protocol LayoutComboProtocol {
	/// 该组合的长度（包含元素个数）。
	var length: Int { get }
	
	/// 是否纵向排列。
	var isVertical: Bool { get }

	/// 该组合的计算参数。
	/// - note:
	/// 	计区域宽度为w，高度为h。有：
	/// 	```
	/// 	w = a * h + b
	/// 	h = c * w + d
	/// 	```
	var parameters: LayoutParameters { get }
}

// MARK: -

/// 简单布局组合。
///
/// 简单布局组合中包含一定数量的元素，并且这些元素处于同一层级。
fileprivate final class SimpleLayoutCombo : LayoutComboProtocol {
	fileprivate init(length: Int, isVertical: Bool, parameters: LayoutParameters) {
		assert(length >= 1)
		
		self.length = length
		self.isVertical = isVertical
		self.parameters = parameters
	}
	
	// MARK: Conform - LayoutComboProtocol
	
	fileprivate let length: Int
	
	fileprivate let isVertical: Bool

	fileprivate let parameters: LayoutParameters
}

// MARK: -

/// 复杂布局组合。
/// 
/// 复杂布局组合y由多个下级布局组合组成。
fileprivate final class ComplexLayoutCombo : LayoutComboProtocol {
	/// 成员数组。
	fileprivate let children: [LayoutComboProtocol]
	
	fileprivate init(
		children: [LayoutComboProtocol],
		isVertical: Bool,
		parameters: LayoutParameters
	) {
		assert(children.count >= 2)
		
		self.children = children
		self.isVertical = isVertical
		self.parameters = parameters
		
		length = children.reduce(0) { return $0 + $1.length }
	}
	
	// MARK: Conform - LayoutComboProtocol
	
	fileprivate let length: Int
	
	fileprivate let isVertical: Bool

	fileprivate let parameters: LayoutParameters
}

// MARK: -

extension CGSize {
	fileprivate var aspectRatio: CGFloat {
		return width / height
	}
	
	fileprivate var inversedAspectRatio: CGFloat {
		return height / width
	}
	
	fileprivate var area: CGFloat {
		return width * height
	}
}

// MARK: -

extension Int {
	fileprivate func minusOne() -> Int {
		return self - 1
	} 
}
