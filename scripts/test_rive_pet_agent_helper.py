import tempfile
import unittest
from pathlib import Path
import xml.etree.ElementTree as ET
import rive_pet_agent_helper as helper


class RigIntegrityTests(unittest.TestCase):
    def repaired(self, mutate):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / 'scene.rml'
            root = ET.parse(helper.SCENE_RML).getroot()
            mutate(root)
            ET.ElementTree(root).write(path, encoding='unicode')
            restored = helper.sanitize_and_restore_databind(path)
            result = ET.parse(path).getroot()
            self.assertEqual(helper.sanitize_and_restore_databind(path), 0)
            return restored, result

    def test_partial_loss_above_old_threshold(self):
        def mutate(root):
            node = next(e for e in root.iter() if e.get('id') == '2:161')
            node.remove(node.find('DataBindContext'))
            self.assertGreater(len(list(root.iter('DataBindContext'))), 40)
        restored, root = self.repaired(mutate)
        self.assertEqual(restored, 1)
        self.assertEqual(len(list(root.iter('DataBindContext'))), 65)

    def test_wrong_binding_source(self):
        def mutate(root):
            node = next(e for e in root.iter() if e.get('id') == '1:32')
            node.find('DataBindContext').set('sourcePathIds', 'wrong')
        restored, _ = self.repaired(mutate)
        self.assertEqual(restored, 1)

    def test_missing_destination_fails_without_overwriting(self):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / 'scene.rml'
            path.write_text('<Rive/>', encoding='utf-8')
            with self.assertRaises(ValueError):
                helper.sanitize_and_restore_databind(path)
            self.assertEqual(path.read_text(encoding='utf-8'), '<Rive/>')


if __name__ == '__main__':
    unittest.main()
