import SwiftUI
import SwiftData

struct AddExpenseDialog: View {
    @Binding var isPresented: Bool
    @Environment(\.modelContext) private var modelContext
    
    @State private var title: String = ""
    @State private var amount: String = ""
    @State private var selectedCategory: String = "Food"
    
    var body: some View {
        ZStack {
            // 背景遮罩
            if isPresented {
                Color.black.opacity(0.5)
                    .ignoresSafeArea()
                    .transition(.opacity)
                    .onTapGesture {
                        withAnimation {
                            isPresented = false
                        }
                    }
            }
            
            // 对话框
            if isPresented {
                VStack(spacing: 0) {
                    // 标题栏
                    HStack {
                        Text("Add Expense")
                            .font(.title2)
                            .fontWeight(.semibold)
                            .foregroundColor(.primary)
                        
                        Spacer()
                        
                        Button(action: {
                            withAnimation {
                                isPresented = false
                            }
                        }) {
                            Image(systemName: "xmark")
                                .foregroundColor(.secondary)
                                .font(.system(size: 20))
                                .frame(width: 40, height: 40)
                                .background(Color.gray.opacity(0.1))
                                .clipShape(Circle())
                        }
                    }
                    .padding(24)
                    .overlay(
                        Divider(),
                        alignment: .bottom
                    )
                    
                    // 表单内容
                    VStack(spacing: 20) {
                        // 描述输入
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Description")
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .foregroundColor(.primary)
                            
                            TextField("What did you spend on?", text: $title)
                                .textFieldStyle(.plain)
                                .padding(12)
                                .background(Color.gray.opacity(0.1))
                                .cornerRadius(12)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(Color.gray.opacity(0.2), lineWidth: 2)
                                )
                        }
                        
                        // 金额输入
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Amount")
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .foregroundColor(.primary)
                            
                            HStack {
                                Text("¥")
                                    .foregroundColor(.secondary)
                                    .font(.body)
                                    .fontWeight(.medium)
                                
                                TextField("0.00", text: $amount)
                                    .keyboardType(.decimalPad)
                                    .textFieldStyle(.plain)
                                    .font(.body)
                                    .padding(.leading, 4)
                            }
                            .padding(12)
                            .background(Color.gray.opacity(0.1))
                            .cornerRadius(12)
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(Color.gray.opacity(0.2), lineWidth: 2)
                            )
                        }
                        
                        // 分类选择
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Category")
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .foregroundColor(.primary)
                            
                            LazyVGrid(columns: [
                                GridItem(.flexible()),
                                GridItem(.flexible()),
                                GridItem(.flexible())
                            ], spacing: 8) {
                                ForEach(categories, id: \.self) { category in
                                    let config = CategoryConfig.config(for: category)
                                    Button(action: {
                                        selectedCategory = category
                                    }) {
                                        Text(category)
                                            .font(.subheadline)
                                            .fontWeight(.medium)
                                            .foregroundColor(selectedCategory == category ? .white : .secondary)
                                            .padding(.horizontal, 16)
                                            .padding(.vertical, 8)
                                            .background(
                                                selectedCategory == category
                                                    ? config.color
                                                    : Color.gray.opacity(0.1)
                                            )
                                            .cornerRadius(20)
                                    }
                                }
                            }
                        }
                        
                        // 提交按钮
                        Button(action: handleSubmit) {
                            Text("Add Expense")
                                .font(.body)
                                .fontWeight(.semibold)
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                                .background(
                                    (title.trimmingCharacters(in: .whitespaces).isEmpty || amount.isEmpty)
                                        ? Color.gray
                                        : Color.indigo
                                )
                                .cornerRadius(12)
                        }
                        .disabled(title.trimmingCharacters(in: .whitespaces).isEmpty || amount.isEmpty)
                    }
                    .padding(24)
                }
                .background(Color.white)
                .cornerRadius(24)
                .padding(.horizontal, 16)
                .transition(.scale.combined(with: .opacity))
            }
        }
        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: isPresented)
    }
    
    private func handleSubmit() {
        guard !title.trimmingCharacters(in: .whitespaces).isEmpty,
              !amount.isEmpty,
              let amountValue = Double(amount) else {
            return
        }
        
        let newExpense = ExpenseItem(
            amount: amountValue,
            title: title.trimmingCharacters(in: .whitespaces),
            date: Date(),
            category: selectedCategory
        )
        
        modelContext.insert(newExpense)
        
        // 重置表单
        title = ""
        amount = ""
        selectedCategory = "Food"
        
        withAnimation {
            isPresented = false
        }
    }
}
