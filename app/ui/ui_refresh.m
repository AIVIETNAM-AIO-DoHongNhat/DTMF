function ui_refresh(app)
%UI_REFRESH Vẽ lại toàn bộ giao diện sau khi S đổi
% Gọi ba hàm vẽ, hiện chuỗi phím đọc được, và dồn mọi lỗi vào ô nhật ký
%   UI_REFRESH(APP) đọc APP.S rồi cập nhật AxWave, AxSpec, AxBars, LblDecoded
%   và TxtLog. Đây là hàm DUY NHẤT được gọi sau mỗi lần S = dtmf_run(S).
%
%   Các bước hoạt động:
%       1. Điền giá trị mặc định cho những trường S còn thiếu. Giao diện lúc
%          mới mở chưa chạy dtmf_run lần nào nên chưa có .info, .iSel, .thr.
%       2. Gọi ba hàm vẽ, MỖI hàm một try/catch riêng: một trục hỏng không
%          được kéo theo hai trục kia.
%       3. LblDecoded hiện S.keysHat.
%       4. Nối mọi thông báo lỗi gom được vào cuối TxtLog.
%
%   Hàm này KHÔNG bao giờ ném lỗi và KHÔNG tính toán gì - mọi con số phải do
%   dtmf_run dọn sẵn, xem CONTRACTS §6(h). Nó chỉ đụng sáu thành phần:
%   AxWave, AxSpec, AxBars, LblDecoded, TxtLog và S.
%
%   Input:
%       app: đối tượng giao diện (DTMFApp), hoặc bất cứ thứ gì có sáu thành
%            phần kể trên - đó là toàn bộ hợp đồng mà hàm này cần.
%
%   Example:
%       app.S = dtmf_run(app.S);
%       ui_refresh(app)

S = app.S;

% Bước 1. Giao diện lúc mới mở chưa gọi dtmf_run lần nào.
macDinh = struct('y',         zeros(1, 0), ...
                 'fs',        8000, ...
                 'meta',      [], ...
                 'keysHat',   blanks(0), ...
                 'info',      struct('E', zeros(8, 0)), ...
                 'iSel',      0, ...
                 'thr',       0, ...
                 'lastError', blanks(0));
ten = fieldnames(macDinh);
for i = 1:numel(ten)
    if ~isfield(S, ten{i})
        S.(ten{i}) = macDinh.(ten{i});
    end
end

loi = {};
if ~isempty(S.lastError)
    loi{end+1} = S.lastError;
end

% Bước 2. Ba lời gọi độc lập nhau. Gộp chung một try/catch thì một lỗi ở trục
% thanh làm mất luôn dạng sóng và phổ đồ - tức mất gần hết thông tin trên màn
% hình chỉ vì hỏng một phần ba.
loi = veAnToan(loi, @() ui_plot_wave(app.AxWave, S.y, S.fs, S.meta));
loi = veAnToan(loi, @() ui_plot_spec(app.AxSpec, S.y, S.fs));

% iSel = 0 nghĩa là không có khung nào; E rỗng làm ui_plot_bars xóa trục.
E = [];
if S.iSel >= 1 && S.iSel <= size(S.info.E, 2)
    E = S.info.E(:, S.iSel);
end
loi = veAnToan(loi, @() ui_plot_bars(app.AxBars, E, S.thr));

% Bước 3.
try
    app.LblDecoded.Text = S.keysHat;
catch ME
    loi{end+1} = ME.message;
end

% Bước 4. Nối vào CUỐI nhật ký cũ, không ghi đè: người dùng cần thấy cả chuỗi
% sự kiện chứ không chỉ lỗi gần nhất.
if ~isempty(loi)
    try
        cu = app.TxtLog.Value;
        if ~iscell(cu)
            cu = cellstr(cu);
        end

        % uitextarea mới dựng có Value = {''} chứ không phải {}. Không bỏ nó
        % thì nhật ký vĩnh viễn mở đầu bằng một dòng trắng.
        if isscalar(cu) && isempty(char(cu{1}))
            cu = {};
        end

        app.TxtLog.Value = [cu(:); loi(:)];
    catch
        % Ghi nhật ký hỏng thì cũng không được làm sập phần vẽ đã xong.
    end
end

end

function loi = veAnToan(loi, fn)
%VEANTOAN Gọi một hàm vẽ, nuốt lỗi và gom thông báo lại.
try
    fn();
catch ME
    loi{end+1} = ME.message;
end
end
