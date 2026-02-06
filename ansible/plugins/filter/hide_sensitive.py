"""
Some filters to hide secrets
"""
from ansible.errors import AnsibleFilterError


class FilterModule:

    def filters(self):
        return {
            'mask_key': self.mask_key,
        }

    def mask_key(self, data, target=[], preserve_blank=True):
        """Mask the content of every instance of keys in a JSON structure"""
        if isinstance(data, dict):
            result = {}
            for k, v in data.items():
                if k in target:
                    result[k] = "***" if (v or not preserve_blank) else None
                else:
                    result[k] = self.mask_key(v, target, preserve_blank)
        elif isinstance(data, list):
            result = [self.mask_key(v, target, preserve_blank) for v in data]
        else:
            result = data
        return result
