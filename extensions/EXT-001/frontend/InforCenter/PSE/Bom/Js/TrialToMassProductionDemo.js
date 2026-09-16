// 试制转量产：只读演示入口。禁止在此文件中调用 DataService、检出、保存或任何 BOM 写入服务。
InforCenter_Custom_TrialToMassProduction_OpenDemo = function (para) {
    var actionPara = para[1] || {};
    var itemCode = actionPara.ItemCode || "";

    // 需求 UC_FD_01_04：仅允许车型级物料。
    if (!/^\w*-(?:1|2)-\w*$/.test(itemCode)) {
        HoteamUI.UIManager.MsgBox(HoteamUI.Language.Lang("PseBomMenu.TrialToMassProductionOnlyModel"));
        return;
    }

    var callback = function (data, ret) {
        // 演示页不修改业务数据；仅让菜单框架完成一次正常返回。
        InforCenter_Platform_MenuCtrl_InnerReceiveServerData(para[0], {
            confirm: ret && ret.confirm === "Cancel" ? "Cancel" : "OK"
        });
    };

    HoteamUI.UIManager.Popup(
        "TrialToMassProductionDemo",
        {
            ItemCode: itemCode,
            ItemName: actionPara.ItemName || "",
            ItemMasterID: actionPara.ItemMasterID || "",
            ViewID: actionPara.ViewID || "",
            ViewType: actionPara.ViewType || "",
            TreeListID: actionPara.TreeListID || ""
        },
        callback,
        {},
        "920*620"
    );
};

InforCenter_Custom_TrialToMassProductionDemo_OnCreate = function (pageEvent) {
    var page = pageEvent.o;
    var para = page.GetPara();

    page.GetControl("CurrentItemCode").SetText(para.ItemCode || "");
    page.GetControl("CurrentItemName").SetText(para.ItemName || "");
    page.GetControl("CurrentViewType").SetText(para.ViewType || "");
    page.GetControl("RuleDescription").SetText(
        "演示范围：仅展示规则和导出，不创建基线、不创建或替换物料、不写颜色表、不调用 SAP。\r\n" +
        "已确认规则：匹配物料必须全量转码，不支持逐项取消；若中间层级物料不匹配，则排除该中间层级以下整个分支。"
    );
};

InforCenter_Custom_TrialToMassProductionDemo_LoadRows = function (ctrlEvent) {
    // 仅为用户确认的演示映射；不从服务端读取或写入数据。
    ctrlEvent.o.LoadGridRows({
        RecordsTotal: 3,
        Rows: [
            {
                SOURCECODE: "8125A-2CDB-A505",
                SOURCENAME: "试制车架总成",
                TARGETCODE: "8125A-2CD -A500",
                RESULT: "全量转码"
            },
            {
                SOURCECODE: "81300-2CDB-A600",
                SOURCENAME: "试制前叉总成",
                TARGETCODE: "81300-2CD -A600",
                RESULT: "全量转码"
            },
            {
                SOURCECODE: "82100-2CDB-A617-M1_TYPE1",
                SOURCENAME: "试制线束总成",
                TARGETCODE: "82100-2CD -A610-M1_TYPE1",
                RESULT: "全量转码"
            }
        ]
    });
};

InforCenter_Custom_TrialToMassProductionDemo_Export = function () {
    // 导出只保留用户确认的两列。
    var csv = "原物料编码,原物料名称\r\n" +
        "8125A-2CDB-A505,试制车架总成\r\n" +
        "81300-2CDB-A600,试制前叉总成\r\n" +
        "82100-2CDB-A617-M1_TYPE1,试制线束总成\r\n";
    var blob = new Blob(["\ufeff" + csv], { type: "text/csv;charset=utf-8" });
    var url = window.URL.createObjectURL(blob);
    var anchor = document.createElement("a");
    anchor.href = url;
    anchor.download = "待转码物料清单_演示.csv";
    document.body.appendChild(anchor);
    anchor.click();
    document.body.removeChild(anchor);
    window.URL.revokeObjectURL(url);
};

InforCenter_Custom_TrialToMassProductionDemo_Close = function (ctrlEvent) {
    HoteamUI.UIManager.Return(ctrlEvent.o.ContainerID(), { confirm: "OK" });
};
