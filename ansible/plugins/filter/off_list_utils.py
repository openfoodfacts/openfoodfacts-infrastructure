"""
Some filters useful to avoid complex expressions in specific case
"""
from ansible.errors import AnsibleFilterError

class FilterModule:

    def filters(self):
        return {
            'flatten_inner_item': self.flatten_inner_item,
        }

    def flatten_inner_item(self, data, indice):
        """given a list of list, where one of the inner list element is a list,
        flatten that element, repeating the rest of the list
        """
        result = []
        for num, item in enumerate(data):
            if not isinstance(item, list):
                raise AnsibleFilterError(
                    "List number (%d) is not a list",
                    num
                )
            if len(item) <= indice:
                raise AnsibleFilterError(
                    "List number (%d) of the list as two few items (%d)",
                    num,
                    len(item)
                )
            for subitem in item[indice]:
                newitem = list(item)
                newitem[indice] = subitem
                result.append(newitem)
        return result


if __name__ == "__main__":
    # tests
    mod = FilterModule()

    result = mod.flatten_inner_item([], indice=2)
    assert result == []
    result = mod.flatten_inner_item([["a", [], "b"]], indice=1)
    assert result == []
    result = mod.flatten_inner_item([["a", [1], "b"]], indice=1)
    assert result == [["a", 1, "b"]]
    result = mod.flatten_inner_item([["a", [1, 2, 3], "b"]], indice=1)
    assert result == [["a", 1, "b"], ["a", 2, "b"], ["a", 3, "b"]]
