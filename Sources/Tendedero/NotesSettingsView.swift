import AppKit
import SwiftUI
import NotesCore

struct NotesSettingsView: View {
    @AppStorage("notesTheme") private var theme = "system"
    @AppStorage("notesPaper") private var paper = "blue"
    @AppStorage("notesFontSize") private var fontSize = 23.0
    @AppStorage("notesAutoHang") private var autoHang = false
    @AppStorage("notesReduceMotion") private var reduceMotion = false
    @Namespace private var appearanceSelection

    private let appearances = [(value: "system", title: "跟随系统"), (value: "light", title: "浅色"), (value: "dark", title: "深色")]
    private let fontSizes = [(value: 18.0, title: "紧凑 · 18"), (value: 23.0, title: "舒适 · 23"), (value: 24.0, title: "大字 · 24")]
    private var paperTitle: String { (NotePaper(rawValue: paper) ?? .blue).chineseName }
    private var fontTitle: String { fontSizes.first(where: { $0.value == fontSize })?.title ?? "舒适 · 23" }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .center) {
                if let icon = NotesAppIcon.image() {
                    Image(nsImage: icon).resizable().scaledToFit().frame(width: 42, height: 42)
                        .accessibilityLabel(NotesAppIcon.displayName + "应用图标，" + (NotesAppIcon.isDark ? "深色" : "浅色"))
                }
                Text(NotesAppIcon.displayName + "偏好设置").font(.system(size: 25, weight: .semibold))
                Spacer()
                NotesCloseWindowButton()
            }.padding(30).background(alignment: .top) { NotesWindowDragRegion().frame(height: 24) }
            Form {
                Section("新建便笺") {
                    HStack {
                        Text("默认纸张")
                        Spacer()
                        NotesMenuButton("默认纸张", alignment: .trailing, menu: paperMenu) {
                            HStack(spacing: 9) {
                                Circle().fill(NotesTheme.paper(NotePaper(rawValue: paper) ?? .blue)).overlay(Circle().stroke(NotesTheme.border, lineWidth: 1)).frame(width: 13, height: 13)
                                Text(paperTitle)
                                dropdownChevron
                            }.padding(.horizontal, 11).frame(height: 32)
                                .background(NotesTheme.shell, in: RoundedRectangle(cornerRadius: 8))
                                .overlay(RoundedRectangle(cornerRadius: 8).stroke(NotesTheme.border, lineWidth: 1))
                                .contentTransition(.opacity).animation(NotesMotion.quick, value: paper)
                        }.fixedSize()
                    }
                    Toggle("新建便笺自动挂上", isOn: $autoHang).tint(NotesTheme.accent).animation(NotesMotion.quick, value: autoHang).notesTooltip("新建便笺时自动挂到绳上")
                    Text("默认先保存为草稿，写好后再挂上。已取下和草稿都可在全部便笺中找到。").font(.system(size: 12)).foregroundStyle(NotesTheme.muted)
                }
                Section("外观") {
                    HStack(spacing: 18) {
                        Text("外观")
                        Spacer(minLength: 10)
                        appearanceControl
                    }
                    HStack {
                        Text("正文字号")
                        Spacer()
                        NotesMenuButton("正文字号", alignment: .trailing, menu: fontMenu) {
                            HStack(spacing: 9) { Text(fontTitle); dropdownChevron }
                                .padding(.horizontal, 11).frame(height: 32)
                                .background(NotesTheme.shell, in: RoundedRectangle(cornerRadius: 8))
                                .overlay(RoundedRectangle(cornerRadius: 8).stroke(NotesTheme.border, lineWidth: 1))
                                .contentTransition(.opacity).animation(NotesMotion.quick, value: fontSize)
                        }.fixedSize()
                    }
                    Toggle("减少动态", isOn: $reduceMotion).tint(NotesTheme.accent).notesTooltip("减少窗口过渡和交互动效")
                    Text("系统开启减少动态时也会生效。").font(.system(size: 12)).foregroundStyle(NotesTheme.muted)
                }
                Section("数据与快捷键") {
                    Text("便笺及附件副本保存在本机。移到最近删除后可手动恢复；永久删除需要再次确认。").font(.system(size: 12)).foregroundStyle(NotesTheme.muted)
                    Text("⌘N 新建　⌘F 搜索　⌘Z 撤销\n⌘B / I / U 文字格式　Esc 收起").font(.system(size: 12)).foregroundStyle(NotesTheme.muted)
                    Text("截图监听、挂绳和系统全局快捷键请使用菜单栏中已有的设置入口。").font(.system(size: 12)).foregroundStyle(NotesTheme.muted)
                }
            }.formStyle(.grouped).scrollContentBackground(.hidden).scrollIndicators(.never)
        }.foregroundStyle(NotesTheme.text).background(NotesTheme.shell).clipShape(RoundedRectangle(cornerRadius: 30))
    }
    private var dropdownChevron: some View {
        Image(systemName: "chevron.down").font(.system(size: 9, weight: .semibold)).foregroundStyle(NotesTheme.muted)
    }
    private var appearanceControl: some View {
        HStack(spacing: 2) {
            ForEach(appearances, id: \.value) { appearance in
                Button { withAnimation(NotesMotion.selection) { theme = appearance.value } } label: {
                    Text(appearance.title).font(.system(size: 12, weight: theme == appearance.value ? .medium : .regular))
                        .foregroundStyle(theme == appearance.value ? NotesTheme.accent : NotesTheme.muted)
                        .padding(.horizontal, 12).frame(height: 30)
                        .background {
                            if theme == appearance.value {
                                RoundedRectangle(cornerRadius: 7).fill(NotesTheme.shell)
                                    .overlay(RoundedRectangle(cornerRadius: 7).stroke(NotesTheme.border.opacity(0.8), lineWidth: 1))
                                    .matchedGeometryEffect(id: "appearanceSelection", in: appearanceSelection)
                            }
                        }.contentShape(Rectangle())
                }.buttonStyle(NotesPressStyle()).accessibilityLabel("外观：" + appearance.title).notesTooltip("外观：" + appearance.title)
                    .accessibilityAddTraits(theme == appearance.value ? [.isSelected] : [])
            }
        }.padding(3).background(NotesTheme.paper(.blue), in: RoundedRectangle(cornerRadius: 10))
            .accessibilityElement(children: .contain).accessibilityLabel("外观")
    }
    private func paperMenu() -> NSMenu {
        let menu = NSMenu()
        for value in NotePaper.allCases {
            let item = ClosureMenuItem(value.chineseName) { paper = value.rawValue }
            item.state = paper == value.rawValue ? .on : .off
            menu.addItem(item)
        }
        return menu
    }
    private func fontMenu() -> NSMenu {
        let menu = NSMenu()
        for size in fontSizes {
            let item = ClosureMenuItem(size.title) { fontSize = size.value }
            item.state = fontSize == size.value ? .on : .off
            menu.addItem(item)
        }
        return menu
    }
}
