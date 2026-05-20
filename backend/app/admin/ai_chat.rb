ActiveAdmin.register_page "AI Chat" do
  menu priority: 2, label: "AI Layer Assistant"

  content title: "AI Layer Assistant" do
    render partial: "admin/ai_chat/chat_panel"
  end
end
