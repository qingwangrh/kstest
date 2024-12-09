from jinja2 import Environment, BaseLoader, FileSystemLoader
import yaml
import os
import subprocess

def execute_command(command):
    try:
        # 执行命令并捕获输出
        result = subprocess.run(command, capture_output=True, text=True, check=True,shell=True)
        print(command)
        # # 打印输出
        # print("stdout:", result.stdout)
        # print("stderr:", result.stderr)
        # print("returncode:", result.returncode)
        return result
    except subprocess.CalledProcessError as e:
        print("Command failed with return code", e.returncode)
        print("stdout:", e.stdout)
        print("stderr:", e.stderr)

# 执行多个命令
# execute_command(['ls', '-l'])
# execute_command(['cat', '/etc/hosts'])
# execute_command(['echo', 'Hello, World!'])

# 定义模板字符串
template_str = """
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: {{name}}
  namespace: ks-test
spec:
  storageClassName: {{sc}}
  volumeMode: {{mode}}
  resources:
    requests:
      storage: {{size}}
  accessModes:
    - {{access}}
"""
namespace="ks-test"
file_loader = FileSystemLoader('templates')
# 创建 Jinja2 环境
env = Environment(loader=file_loader)

# 创建模板对象
template = env.get_template('pvc.yaml')


# 准备数据
data_base = {
    'name': 'ks-pvc',
    'namespace':namespace,
    'sc': 'ks-san',
    'mode': 'Block',
    'size': '256Mi',
    'access': 'ReadWriteOnce'
}

for i in range(10):
    data=data_base.copy()
    data["name"]=data_base["name"]+str(i)
    # 渲染模板
    rendered_yaml = template.render(data)

    # 打印渲染后的 YAML
    # print(rendered_yaml)

    # 保存到文件
    filename='./tmpl/my-pvc{}.yaml'.format(i)
    with open(filename, 'w') as file:
        file.write(rendered_yaml)

    # # 验证生成的 YAML
    # try:
    #     parsed_yaml = yaml.safe_load(rendered_yaml)
    #     # print("YAML is valid.")
    # except yaml.YAMLError as e:
    #     print(f"YAML is invalid: {e}")

execute_command("oc get ns {0} || oc create ns {0}".format(namespace))

for i in range(10):
    filename='./tmpl/my-pvc{}.yaml'.format(i)
    execute_command("oc apply -f {}".format(filename))

# execute_command("oc apply -f {}".format(filename))
# print(execute_command("oc get pvc -n {}".format(namespace)).stdout)
# execute_command("oc delete pvc ks-pvc -n {}".format(namespace))