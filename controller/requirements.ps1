function Get-RequirementQuestions($Config) {
    $c=Initialize-ExtensionWorkflow $Config
    if ($c.workflow.phase -notin @('Requirements','Draft','ChangesRequested')) { return @() }
    $missing=@()
    if ($c.workflow.capability_mode -eq 'legacy') { return @() }
    if ($c.workflow.stage -eq 'prototype') {
        if (!$c.requirements.change_goal) { $missing+='原型要解决什么问题、谁会使用？' }
        if (!$c.requirements.user_scenario) { $missing+='用户从哪里进入、按什么顺序完成操作？' }
        if (@($c.requirements.inputs).Count -eq 0) { $missing+='是否需要用户提供数据？如果不需要，使用生成演示数据还是无数据？' }
        if ($c.delivery.demo_data -eq 'pending') { $missing+='演示数据来源是用户提供、自动生成，还是不使用？' }
        if ($c.delivery.backend -eq 'pending') { $missing+='是否需要后端、接口或数据库写入？' }
        if (!(Get-NormalizedNavigationPath $c.target.navigation_path)) { $missing+='原产品中要参考哪条点击路径的页面样式？' }
        if (@($c.requirements.ui_and_interaction).Count -eq 0) { $missing+='页面要展示哪些字段和操作，操作后如何反馈？' }
        if (@($c.requirements.acceptance_criteria).Count -eq 0) { $missing+='怎样判断原型可以验收？' }
        if (@($c.requirements.constraints).Count -eq 0 -or @($c.requirements.out_of_scope).Count -eq 0) { $missing+='有哪些限制和明确不做的内容？' }
    } else {
        if (!$c.integration_requirements.source_artifact) { $missing+='要嵌入哪个已完成的 HTML 页面？请给出文件路径或扩展产物。' }
        if ($c.integration_requirements.source_kind -eq 'pending') { $missing+='页面来自本扩展，还是用户提供的文件？' }
        if (!(Get-NormalizedNavigationPath $c.target.navigation_path)) { $missing+='PLM 用户点击哪条菜单路径打开页面？' }
        if (@($c.target.mount_sequence).Count -eq 0) { $missing+='菜单定义、页面注册、容器或 Iframe、最终资源的技术定位顺序是什么？' }
        if (!$c.integration_requirements.entry_behavior) { $missing+='页面在原产品中如何打开、返回和传参？' }
        if ($c.original_system_change.snapshot_confirmed -ne $true) { $missing+='原系统文件是否已完成备份或快照？' }
        if (@($c.integration_requirements.acceptance_criteria).Count -eq 0) { $missing+='嵌入后的验收条件是什么？' }
        if (@($c.integration_requirements.constraints).Count -eq 0 -or @($c.integration_requirements.out_of_scope).Count -eq 0) { $missing+='嵌入有哪些限制和不在范围的内容？' }
    }
    @($missing)
}
