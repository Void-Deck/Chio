enum ToolFailure {
    case invalid(String)
}
extension ToolFailure: Error {}
