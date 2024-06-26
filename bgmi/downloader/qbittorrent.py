import qbittorrentapi
from qbittorrentapi import TorrentState

from bgmi.config import cfg
from bgmi.session import session
from bgmi.plugin.download import BaseDownloadService, DownloadStatus


class QBittorrentWebAPI(BaseDownloadService):
    def __init__(self):
        self.client = qbittorrentapi.Client(
            host=cfg.qbittorrent.rpc_host,
            port=cfg.qbittorrent.rpc_port,
            username=cfg.qbittorrent.rpc_username,
            password=cfg.qbittorrent.rpc_password,
        )
        self.client.auth_log_in()

    @staticmethod
    def check_config() -> None:
        pass

    def add_download(self, url: str, save_path: str):
        torrent_resp = session.get(url)

        torrent_resp.raise_for_status()
        torrent_file = torrent_resp.content

        self.client.torrents_add(
            torrent_files={'torrents': torrent_file},
            category=cfg.qbittorrent.category,
            save_path=save_path,
            is_paused=False,
            use_auto_torrent_management=False,
            tags=cfg.qbittorrent.tags,
        )

        info = self.client.torrents_info(sort="added_on")

        if info:
            for torrent in info:
                if torrent.save_path == save_path:
                    return torrent.hash
            return info[-1].hash
        return None

    def get_status(self, id: str) -> DownloadStatus:
        torrent = self.client.torrents.info(torrent_hashes=id)
        if not torrent:
            return DownloadStatus.not_found
        state_enum: TorrentState = torrent[0].state_enum
        if state_enum.is_complete or state_enum.is_uploading:
            return DownloadStatus.done
        if state_enum.is_errored:
            return DownloadStatus.error
        if state_enum.is_paused:
            return DownloadStatus.not_downloading
        if state_enum.is_downloading or state_enum.is_checking:
            return DownloadStatus.downloading
        return DownloadStatus.error
