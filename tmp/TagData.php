<?php
/**
 *
 *
 * */
class TagData extends ApiData
{
        private $user;

        private $parameters;

        private $alias = 't';

        private $responseFieldMap = array('tags' => '');

        private $extraFields;

        private $objectInfo = array('object' => 'tags', 'child' => 'tag');

        private $method;

        private $response;

        private $content;

        private $errors = false;

        private $allDataMode = false;

   /*
   * @param User $user   Текущий пользователь, с данными которого работает API.
   */
        public function __construct(User $user,$allDataMode = false)
        {
                $this->allDataMode = $allDataMode;
                $this->setUser($user);
        }

   /*
   *
   * @param User $user   Текущий пользователь, с данными которого работает API.
   */

        public function responseBuilder($parameters)
        {
                $this->setMethod($parameters['objectMethod']);
                $this->prepareParameters($parameters);
                $parameters = $this->getParameters();

                $this->preResponseBuilder();

                //Определяем какой метод пришел
                $method = $this->getMethod();
                //Обращаемся к методу(get,post,set)
                $this->$method();

                $response  = $this->getResponse();

                $this->addRequestToResponse($response);

                //$response += $this->objectInfo;
                return $response;
        }

        public function getResponse()
        {
                return $this->response;
        }

        public function getUser()
        {
                return $this->user;
        }

        public function setUser(User $user)
        {
                $this->user = $user;
        }

        public function getContent()
        {
                return $this->content;
        }

        public function setContent($content)
        {
                $this->content = $content;
        }

        public function setErrors($error)
        {
                $this->errors[] = $error;
        }

        private function get()
        {
                $parameters = $this->prepareValueForMethodQuery($this->getParameters());
                $dataResult = TagTable::apiGetTags($parameters,$this->getUser()->getId(),$this->alias);
                $response = $this->prepareResponse($dataResult);
                $response = $this->buildResponse($response);
                $this->setResponse($response);
        }

        private function set()
        {
                $data = $this->getContent();
                $records = array();
                if (isset($data['tags']) && is_array($data['tags']) && !empty($data['tags']))
                        $records = $data['tags'];
                elseif (isset($data['name']) || isset($data['id']) || isset($data['deleted_at']))
                        $records = array($data);
                else
                {
                        $this->setResponse(false);
                        return;
                }
                $result = $this->checkAndUpdateRecord($records);
                $this->setResponse($result);
        }

        private function post()
        {
                $data = $this->getContent();
                $records = array();
                if (isset($data['tags']) && is_array($data['tags']) && !empty($data['tags']))
                        $records = $data['tags'];
                elseif (isset($data['name']))
                        $records = array($data);
                else
                {
                        $this->setResponse(false);
                        return;
                }
                $result = $this->checkAndSaveNewRecord($records);
                $this->setResponse($result);
        }

        public function buildResponse($response)
        {
                $result = array('tags' =>  $response);
                if($this->getErrors())
                        $result['errors'] = $this->getErrors();
                return $result;
        }

        private function checkAndUpdateRecord($records)
        {
                $result = array();
                if (empty($records))
                        return $result;

                foreach ($records as $record)
                {
                        $id = null;
                        if (isset($record['id']) && $record['id'])
                                $id = $record['id'];
                        elseif ($tagId = $this->getTagIdParam())
                                $id = $tagId;

                        if (!$id)
                        {
                                $this->setErrors(array('type' => 'tag_required_id', 'text' => "No contain field 'id'."));
                                continue;
                        }

                        $tag = Doctrine_Core::getTable('Tag')->findOneBy('id', $id);
                        if (!$tag || $tag->getUserId() != $this->getUser()->getId())
                        {
                                $this->setErrors(array('type' => 'tag_not_found', 'text' => ''));
                                continue;
                        }

                        if (isset($record['name']) && $record['name'] !== '')
                                $tag->setName($record['name']);
                        if (isset($record['updated_at']))
                                $tag->setUpdatedAt($record['updated_at']);
                        if (isset($record['deleted_at']) && $record['deleted_at'] && $record['deleted_at'] != 'null')
                                $tag->setDeletedAt($record['deleted_at']);

                        $tag->save();
                        $result[] = array('id' => $tag->getId());
                }
                return $result;
        }

        private function checkAndSaveNewRecord($records)
        {
                $result = array();
                if (empty($records))
                        return $result;

                foreach ($records as $record)
                {
                        if (!isset($record['name']) || $record['name'] === '')
                        {
                                $this->setErrors(array('type' => 'tag_required_name', 'text' => ''));
                                continue;
                        }

                        $tag = new Tag();
                        $tag->setUserId($this->getUser()->getId());
                        $tag->setName($record['name']);
                        if (isset($record['created_at']))
                                $tag->setCreatedAt($record['created_at']);
                        if (isset($record['updated_at']))
                                $tag->setUpdatedAt($record['updated_at']);
                        $tag->save();
                        $result[] = array('id' => $tag->getId(), 'name' => $tag->getName());
                }
                return $result;
        }

        private function getTagIdParam()
        {
                $params = $this->getParameters();
                if (isset($params['tag_id']['value']) && $params['tag_id']['value'])
                        return $params['tag_id']['value'];
                return null;
        }

        private function getErrors()
        {
                return $this->errors;
        }

        private function setResponse($response)
        {
                $this->response = $response;
        }

        private function prepareResponse($response)
        {
                if (empty($response))
                        return $response;

                $result = array();
                $fields = sfConfig::get('fields_mapping_tags_fields');
                foreach ($response as $key=>$element)
                {
                        $main = array_intersect_key($element,$fields);
                        $extra = array_intersect_key($element,$this->extraFields);
                        $result[$key] = array_merge($main,$extra);
                }
                return $result;
        }

        protected function getParameters()
        {
                return $this->parameters;
        }

        private function setParameters($parameters)
        {
                $this->parameters = $parameters;
        }

        private function getMethod()
        {
                return $this->method;
        }

        private function setMethod($method)
        {
                $this->method = $method;
        }

        private function prepareParameters($parameters)
        {
                $this->setParameters($this->getDefaultParameters($parameters));
        }

        private function getDefaultParameters($parameters)
        {
                //TODO:Если это post запрос выбираем данные. Потом ансетим данные(content), еще не придумал как красиво это обойти.Нужно доделать.
                if (isset($parameters['content']))
                {
                        $this->setContent($parameters['content']);
                        unset($parameters['content']);
                }
                $baseConfig = $this->getBaseDefaultParameters($parameters);
                $methodConfig = $this->getMethodDefaultParameters($parameters);
                $allConfig = array_merge($baseConfig,$methodConfig);
                return $allConfig;
        }

        private function getBaseDefaultParameters($parameters)
        {
                $baseConfigs = sfConfig::get('rest_main_parameters_config');
                $configKeys = array_keys($baseConfigs);
                $configKeys = array_fill_keys($configKeys,false);
                $baseParameters = array_merge($configKeys,$parameters);
                foreach ($baseParameters as $key=>$value)
                {
                        $baseParameters[$key] = array('value' => $value);
                        if (isset($baseConfigs[$key]['default']))
                                $baseParameters[$key]['default'] = $baseConfigs[$key]['default'];
                        if ($key == 'limit' && $value)
                        {
                                $value = ltrim(rtrim($value,','),',');
                                if (strstr($value, ','))
                                {
                                        $offset_limit = explode(',', $value);
                                        $result['offset'] = $offset_limit['0'];
                                        $result['limit'] = $offset_limit['1'];
                                        $baseParameters[$key] = array('value' => $result);
                                }
                        }
                }
                return $baseParameters;
        }

        private function getMethodDefaultParameters($parameters)
        {
                //Получаем параметры разрешенных запросов для текущего метода в API. Используем теже конфиги, что и для REST FULL
                $methodConfigs = sfConfig::get('rest_parameters_tags.'.$parameters['objectMethod']);
                $configKyes = array_keys($methodConfigs);
                $configKyes = array_fill_keys($configKyes,false);
                $methodParameters = array_intersect_key($parameters,$configKyes);
                $methodParameters = array_merge($configKyes,$methodParameters);
                //Заполняем дефолтные значения и значения которые были переданы для каждого ключа
                foreach ($methodParameters as $key=>$value)
                {
                        $methodParameters[$key] = array('value' => $value);
                        if (isset($methodConfigs[$key]['default']))
                                $methodParameters[$key]['default'] = $methodConfigs[$key]['default'];
                        if ($key == 'fields')
                        {
                                if ($methodParameters[$key]['value']  && !$this->allDataMode)
                                {
                                        $buildParameters = $this->getMappingValueWhithRequestValue('fields', $methodParameters[$key]['value']);
                                        $methodParameters[$key]['value'] =      $buildParameters['value'];
                                        $methodParameters[$key]['extra'] =      $buildParameters['extra'];
                                }
                                else
                                {
                                        $methodParameters[$key]['value'] = false;
                                        $buildParameters = $this->getMappingValue('fields', $methodParameters[$key]['default']);
                                        $methodParameters[$key]['default'] =    $buildParameters['value'];
                                        $methodParameters[$key]['extra'] =      $buildParameters['extra'];
                                }
                        }
                        if ($key == 'options')
                                $methodParameters[$key] = $this->prepareOptions($parameters['objectMethod'],$methodParameters[$key]['value']);
                        if ($key == 'tags_list' && $value)
                                $methodParameters[$key] = array('value' => explode(',', $value));
                }
                return $methodParameters;
        }

        private function getMappingValue($objectName,$defaultValue)
        {
                $defaultFieldsValue = sfConfig::get('fields_mapping_tags_'.$objectName);
                $value = implode(',',$defaultFieldsValue);
                $extra = array_diff_key(array_flip(explode(',', $defaultValue)),$defaultFieldsValue);
                $extra = array_fill_keys(array_flip($extra),true);
                $this->extraFields = $extra;
                return array('value' => $value,'extra' => $extra);
        }

        private function getMappingValueWhithRequestValue($objectName,$requestValue)
        {
                $defaultValue = sfConfig::get('fields_mapping_tags_'.$objectName);

                $value = array_intersect_key($defaultValue,array_flip(explode(',', $requestValue)));
                $value = implode(',', $value);
                $extra = array_diff_key(array_flip(explode(',', $requestValue)),$defaultValue);
                $extra = array_fill_keys(array_flip($extra),true);
                $this->extraFields = $extra;
                return array('value' => $value,'extra' => $extra);
        }

        private function prepareOptions($methodName,$value = false,$object = 'tags')
        {
                $result = array();
                $config = sfConfig::get('rest_parameters_'.$object.'.'.$methodName);
                $config = $config['options']['value'];
                $config = array_fill_keys(explode(',', $config),false);
                if ($value)
                {
                        $value = array_fill_keys(explode(',', $value),true);
                        $value = array_merge($config,$value);
                        $result = $value;
                }
                else
                        $result = $config;
                return $result;
        }

        private function prepareValueForMethodQuery($value)
        {
                $type = $value['fields']['value'] ? 'value' : 'default';
                $queryString = explode(',', $value['fields'][$type]);
                $defaultFieldsValue = sfConfig::get('fields_mapping_tags_fields');
                foreach ($queryString as $key=>$element)
                {
                        $queryString[$key] = '('.$this->alias.'.'.$element.') as '.array_search($element,$defaultFieldsValue);
                }
                $queryString  = implode(',', $queryString);
                $value['fields'][$type] = $queryString;
                return $value;
        }
}
