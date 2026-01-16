import SwiftUI

enum TabItem: Int, CaseIterable {
    case timeline = 0
    case analysis = 1
    case assets = 2
    case settings = 3
    
    var icon: String {
        switch self {
        case .timeline: return "doc.text.fill"
        case .analysis: return "chart.pie.fill"
        case .assets: return "creditcard.fill"
        case .settings: return "gearshape.fill"
        }
    }
    
    var title: String {
        switch self {
        case .timeline: return "时间线"
        case .analysis: return "分析"
        case .assets: return "资产"
        case .settings: return "设置"
        }
    }
}

struct CustomTabBar: View {
    @Binding var selectedTab: TabItem
    var onQuickAdd: () -> Void
    var onTimelineDoubleTap: () -> Void
    
    var body: some View {
        HStack(spacing: 0) {
            // Tab 1: Timeline
            tabButton(
                tab: .timeline,
                icon: TabItem.timeline.icon,
                title: TabItem.timeline.title,
                onDoubleTap: onTimelineDoubleTap
            )
            
            Spacer()
            
            // Tab 2: Analysis
            tabButton(
                tab: .analysis,
                icon: TabItem.analysis.icon,
                title: TabItem.analysis.title,
                onDoubleTap: nil
            )
            
            Spacer()
            
            // Center: Quick Add Button
            quickAddButton
            
            Spacer()
            
            // Tab 3: Assets
            tabButton(
                tab: .assets,
                icon: TabItem.assets.icon,
                title: TabItem.assets.title,
                onDoubleTap: nil
            )
            
            Spacer()
            
            // Tab 4: Settings
            tabButton(
                tab: .settings,
                icon: TabItem.settings.icon,
                title: TabItem.settings.title,
                onDoubleTap: nil
            )
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .padding(.bottom, 8)
        .background(
            ZStack {
                // 背景模糊效果
                Color.white
                    .opacity(0.95)
                
                // 顶部边框
                VStack {
                    Divider()
                        .opacity(0.2)
                    Spacer()
                }
            }
            .shadow(color: .black.opacity(0.08), radius: 20, x: 0, y: -5)
        )
    }
    
    // MARK: - Quick Add Button
    private var quickAddButton: some View {
        Button(action: {
            let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
            impactFeedback.impactOccurred()
            onQuickAdd()
        }) {
            ZStack {
                // 外圈渐变背景
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [Color.blue, Color.blue.opacity(0.8)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 64, height: 64)
                    .shadow(color: Color.blue.opacity(0.4), radius: 12, x: 0, y: 6)
                    .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
                
                // 内圈白色背景
                Circle()
                    .fill(Color.white)
                    .frame(width: 56, height: 56)
                
                // Plus 图标
                Image(systemName: "plus")
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundColor(.blue)
            }
        }
        .offset(y: -12)
        .scaleEffect(1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.6), value: selectedTab)
    }
    
    // MARK: - Tab Button
    @ViewBuilder
    private func tabButton(tab: TabItem, icon: String, title: String, onDoubleTap: (() -> Void)?) -> some View {
        Button(action: {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                if selectedTab == tab, let onDoubleTap = onDoubleTap {
                    onDoubleTap()
                } else {
                    selectedTab = tab
                }
            }
        }) {
            VStack(spacing: 4) {
                ZStack {
                    // 选中状态的背景圆圈
                    if selectedTab == tab {
                        Circle()
                            .fill(Color.blue.opacity(0.1))
                            .frame(width: 40, height: 40)
                            .transition(.scale.combined(with: .opacity))
                    }
                    
                    // 图标
                    Image(systemName: icon)
                        .font(.system(size: 22, weight: selectedTab == tab ? .semibold : .regular))
                        .foregroundColor(selectedTab == tab ? .blue : .gray.opacity(0.6))
                        .scaleEffect(selectedTab == tab ? 1.1 : 1.0)
                }
                .frame(width: 44, height: 44)
                
                // 标签文字
                Text(title)
                    .font(.system(size: 10, weight: selectedTab == tab ? .medium : .regular))
                    .foregroundColor(selectedTab == tab ? .blue : .gray.opacity(0.6))
                    .opacity(selectedTab == tab ? 1.0 : 0.8)
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(PlainButtonStyle())
    }
}
