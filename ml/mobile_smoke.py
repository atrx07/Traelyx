"""Create generated-only export assets for CI; never loads public/private datasets."""

import argparse
from pathlib import Path

import numpy as np
import torch

from . import eventnet as net, mobile_export as mobile


def run(destination):
    torch.set_num_threads(1)
    torch.manual_seed(7)
    values = mobile.generated_inputs()
    normalizer = net.fit_normalizer(torch.from_numpy(np.concatenate(values)))
    mobile.export_pair(net.EventNet(), normalizer, values, destination)
    sessions = {kind: mobile.session(destination / name) for kind, name in mobile.MODEL_FILES.items()}
    mobile.write_fixtures(destination, sessions, 1.0, False)


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('destination', type=Path)
    run(parser.parse_args().destination)
