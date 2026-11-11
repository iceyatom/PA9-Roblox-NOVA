"""Collection export contract tests; no writes to the user's inventory edits."""
import unittest
from map_bridge import inventory_source

class CollectionExportTests(unittest.TestCase):
    def test_legacy_export_remains_accepted(self):
        self.assertIn('return {',inventory_source({'version':1,'items':[],'crates':[]}))

    def test_collection_membership_names_and_unassigned_round_trip(self):
        source=inventory_source({'version':1,'items':{'skin_mint':{'collectionId':'custom'},'skin_ember':{'collectionId':False}},'crates':[],
                                 'collections':{'custom':{'name':'A "Mixed" Collection'},'set:Dragonforge':{'name':'Dragonforge Plus'}}})
        self.assertIn('["collectionId"] = false',source)
        self.assertIn('["collections"]',source)
        self.assertIn('\\034Mixed\\034',source)

    def test_invalid_payloads_are_rejected(self):
        for edit in ({'collectionId':True},{'collectionId':[]},{'collectionId':''},{'collectionId':'bad\nvalue'}):
            with self.subTest(edit=edit),self.assertRaises(ValueError):
                inventory_source({'version':1,'items':{'skin_mint':edit},'crates':{}})
        for definitions in ({'x':{'name':''}},{'x':{'name':'A','script':'return 1'}},{'x':{'name':'bad\nvalue'}},{'x':{'name':'A','deleted':1}}):
            with self.subTest(definitions=definitions),self.assertRaises(ValueError):
                inventory_source({'version':1,'items':{},'crates':{},'collections':definitions})

if __name__=='__main__':
    unittest.main()
