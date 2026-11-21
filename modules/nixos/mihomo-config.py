"""写入 sakura 的本机代理设置。传入的路径是下载时创建的临时文件。"""

from pathlib import Path
import sys

import yaml


def prepare(config):
    if not isinstance(config, dict) or not (
        isinstance(config.get("proxies"), list)
        or isinstance(config.get("proxy-providers"), dict)
    ):
        raise ValueError("订阅需要包含 proxies 列表或 proxy-providers 映射")

    # 端口、模式、规则全部沿用订阅；这里只关掉会影响本机 DNS/路由的开关。
    config["allow-lan"] = False
    # 这台机器使用显式代理。冷启动时 DNS 解析也不能依赖代理规则。
    for section, key in (("tun", "enable"), ("dns", "respect-rules")):
        if config.get(section) is None:
            config[section] = {}
        if not isinstance(config[section], dict):
            raise ValueError(f"{section} 应为 YAML 映射")
        config[section][key] = False
    return config


if __name__ == "__main__":
    path = Path(sys.argv[1])
    try:
        config = prepare(yaml.safe_load(path.read_text(encoding="utf-8")))
    except (yaml.YAMLError, UnicodeError):
        sys.exit("订阅内容不是有效的 UTF-8 YAML")
    except ValueError as error:
        sys.exit(str(error))

    with path.open("w", encoding="utf-8") as output:
        yaml.safe_dump(config, output, allow_unicode=True, sort_keys=False)
