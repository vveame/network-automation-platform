from dto.dashboard_dto import DashboardDTO


class DashboardMapper:
    def to_dict(self, dashboard: DashboardDTO):
        return dashboard.to_dict()
