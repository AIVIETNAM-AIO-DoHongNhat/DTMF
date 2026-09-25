function M = ui_theme()
%UI_THEME Bảng màu, phông chữ và thang màu dùng chung cho DTMFApp
% Một chỗ duy nhất quyết định giao diện trông ra sao - đổi ở đây, đổi toàn bộ
%   M = UI_THEME() trả về struct màu RGB [0..1], tên phông và colormap 256×3.
%   DTMFApp dùng nó khi dựng component; ui_refresh dùng nó khi tô lại ba trục
%   sau mỗi lần vẽ.
%
%   Nguyên tắc: MỘT màu nhấn (chàm đậm) cho mọi thứ "đang được chú ý" - vùng
%   tone, cột vượt ngưỡng, nút chính. Mọi thứ còn lại là thang xám lạnh. Xanh
%   lá và đỏ chỉ dành cho đúng/sai, không dùng để trang trí.
%
%   KHÔNG dùng cho hình báo cáo: ui_plot_* tự mang màu riêng (cam) và
%   test_ui_smoke ghim màu đó. Giao diện tô lại SAU khi ui_plot_* vẽ xong.
%
%   Output:
%       M: struct, các trường
%          .nen .the .vien          nền cửa sổ, nền thẻ, viền thẻ
%          .muc .chuPhu .chuMo      chữ chính, chữ phụ, chữ mờ (nhãn nhỏ)
%          .nhan .nhanNhat          màu nhấn và bản rất nhạt của nó
%          .dung .sai               giải mã khớp / lệch hoặc lỗi
%          .phimPhu .xamCot         nền phím '*' '#', cột dưới ngưỡng
%          .font .fontMono          phông chữ thường và phông đơn cách
%          .cmap                    256×3, trắng -> chàm -> gần đen
%
%   Example:
%       M = ui_theme();
%       colormap(ax, M.cmap)

M = struct();

M.nen      = [0.957 0.961 0.969];   % #F4F5F7
M.the      = [1 1 1];
M.vien     = [0.878 0.890 0.910];   % #E0E3E8

M.muc      = [0.110 0.129 0.169];   % #1C2129
M.chuPhu   = [0.400 0.431 0.482];   % #666E7B
M.chuMo    = [0.580 0.608 0.651];   % #949BA6

M.nhan     = [0.176 0.290 0.557];   % #2D4A8E chàm
M.nhanNhat = [0.910 0.929 0.965];   % #E8EDF6

M.dung     = [0.078 0.478 0.325];   % #147A53
M.sai      = [0.722 0.188 0.188];   % #B83030

M.phimPhu  = [0.953 0.957 0.965];
M.xamCot   = [0.812 0.831 0.863];   % #CFD4DC

% Segoe UI có sẵn trên Windows; máy khác thiếu thì trình duyệt nền của
% uifigure tự rơi về phông sans-serif mặc định, không lỗi.
M.font     = 'Segoe UI';
M.fontMono = 'Consolas';

% Thang màu phổ đồ kiểu hình in: nền nhiễu gần trắng, tone đậm dần sang chàm
% rồi gần đen. Độ sáng giảm ĐƠN ĐIỆU từ đầu tới cuối, nên đọc được cả khi in
% đen trắng - khác parula/jet, nơi vàng sáng lại là mức CAO nhất.
moc = [1.000 1.000 1.000
       0.855 0.886 0.941
       0.463 0.580 0.792
       0.176 0.290 0.557
       0.063 0.082 0.180];
M.cmap = interp1(linspace(0, 1, size(moc, 1)), moc, linspace(0, 1, 256));

end
