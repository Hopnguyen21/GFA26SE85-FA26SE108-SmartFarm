// Luồng chụp thật theo từng bước. Toạ độ {v:[x,y]} và mark [x,y,w,h] viết theo ảnh xem 1188px.
const U = 'owner@smartfarm.demo', P = 'Demo@12345';
const toLogin = [{ v: [215, 1050] }];
const typeCred = (u, p) => [{ v: [590, 1100], text: u }, { v: [590, 1338], text: p }];
const login = [...toLogin, ...typeCred(U, P), { v: [590, 1676] }, { wait: 6000 }];
const B = { back: 1 };
const zone = [{ v: [590, 1100] }, { wait: 3000 }];
const tab = (x) => [{ v: [x, 428] }, { wait: 2500 }];
export const flows = [
  { name: 'dang-nhap', steps: [
    { do: [], file: 'L1_landing.png', mark: [[45, 985, 343, 130]] },
    { do: toLogin, file: 'L2_form.png', mark: [[100, 1035, 985, 130], [100, 1275, 985, 130], [100, 1608, 985, 140]] },
    { do: typeCred(U, P), file: 'L3_dien_xong.png', mark: [[100, 1608, 985, 140]] },
    { do: [{ v: [590, 1676] }, { wait: 6000 }], file: 'L4_trang_chu.png', mark: [[45, 665, 1098, 485], [45, 1190, 535, 215]] },
  ] },
  { name: 'dang-nhap-loi', steps: [
    { do: [...toLogin, ...typeCred(U, 'SaiMatKhau1'), { v: [590, 1676] }, { wait: 4000 }], file: 'LE1_sai_mat_khau.png', mark: [[102, 840, 983, 120]] },
  ] },
  { name: 'cf1', steps: [{ do: login },
    { do: [], file: 'C1_1_trang_chu.png', mark: [[45, 665, 1098, 485], [610, 1195, 535, 215], [610, 1900, 535, 250]] },
    { do: zone, file: 'C1_2_zone.png', mark: [[0, 395, 1188, 100]] },
    { do: tab(766), file: 'C1_3_trien_khai_iot.png', mark: [[0, 395, 1188, 100], [46, 560, 1096, 220]] },
    { do: [{ scroll: 1500 }], file: 'C1_4_du_toan_va_gui.png' },
    { do: [{ v: [1122, 78] }, { wait: 1000 }], file: 'C1_5_menu_zone.png', mark: [[1000, 20, 450, 90]] },
  ] },
  { name: 'cf2', steps: [{ do: login },
    { do: zone, file: 'C2_1_vi_khi_hau.png', mark: [[46, 720, 1096, 70], [46, 858, 1096, 430]] },
    { do: [{ scroll: 1100 }], file: 'C2_2_cuon_xuong.png' },
    { do: [B, { v: [1110, 78] }, { wait: 2500 }], file: 'C2_3_thong_bao.png' },
    { do: [B, { v: [380, 2020] }, { wait: 3000 }], file: 'C2_4_bao_cao.png', mark: [[455, 345, 330, 120], [46, 520, 1096, 840]] },
  ] },
  { name: 'cf3', steps: [{ do: login },
    { do: [...zone, ...tab(340)], file: 'C3_1_thiet_bi.png', mark: [[46, 1080, 1096, 100], [46, 1230, 1096, 120], [46, 1380, 1096, 140]] },
    { do: [{ v: [264, 1284] }, { wait: 2500 }], file: 'C3_2_lich_su_dieu_khien.png' },
    { do: [B, B, { v: [830, 1790] }, { wait: 2500 }], file: 'C3_3_luat_tu_dong.png', mark: [[46, 715, 1096, 535], [935, 780, 155, 95], [776, 2360, 385, 195]] },
    { do: [{ v: [960, 2455] }, { wait: 1500 }], file: 'C3_4_them_moi.png' },
  ] },
  { name: 'cf4', steps: [{ do: login },
    { do: [{ v: [830, 2530] }, { wait: 3500 }], file: 'C4_1_tro_ly_ai.png', mark: [[40, 180, 870, 250], [28, 2330, 990, 115]] },
    { do: [{ v: [500, 2390], text: 'Có cần tưới nước cho cây lúc này không?' }], file: 'C4_2_nhap_cau_hoi.png', mark: [[28, 2330, 990, 115], [1040, 2320, 125, 125]] },
    { do: [{ v: [1100, 2390] }, { wait: 12000 }], file: 'C4_3_ket_qua.png' },
  ] },
];
