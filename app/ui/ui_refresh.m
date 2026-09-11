function ui_refresh(app)
%UI_REFRESH Vẽ lại toàn bộ các trục và nhãn của DTMFApp sau khi S thay đổi.
%   UI_REFRESH(APP) gọi lại 3 hàm vẽ chính và cập nhật các Label/readout.
%
%   Đầu vào:
%       app - đối tượng DTMFApp (có app.S và các thành phần UI).
%
%   Ghi chú kiến trúc:
%       Đây là hàm DUY NHẤT được gọi từ callback sau mỗi lần
%       app.S = dtmf_run(app.S).
%
%   See also dtmf_run, ui_plot_wave, ui_plot_spec, ui_plot_bars.

% TODO(C):
%   try
%       ui_plot_wave(app.AxWave, app.S.y, app.S.fs, app.S.meta);
%       ui_plot_spec(app.AxSpec, app.S.y, app.S.fs);
%       iSel = <khung đang chọn, ví dụ khung cuối có reject khác 'none'>;
%       ui_plot_bars(app.AxBars, app.S.info.E(:,iSel), app.S.thr);
%       app.LblDecoded.Text = app.S.keysHat;
%   catch ME
%       app.TxtLog.Value = [app.TxtLog.Value; {ME.message}];
%   end

error('ui_refresh:notImplemented', 'TODO: cai dat ui_refresh.');

end
